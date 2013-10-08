_        = require 'lodash'
nextTick = require 'next-tick'

# Get the singleton of the router all channels use.
{ currentTransactionId, channelId, router }  = require './router'

class Channel

    # Are we ready yet? When set to false we will block & queue outbound messages.
    ready: no

    # Specifies what the origin of the other `window` must be for the event to be  dispatched.
    #  Either use '*' (indicating no preference) or a URI.
    origin: '*'

    # Scope is prepended to message names. Windows of a single channel must agree upon scope.
    scope: 'testScope'

    # Create a new channel. Provide `window` and `scope` at the least.
    constructor: (opts) ->
        # Expand opts on us.
        ( @[k] = v for k, v of opts )

        # Make sure we do not communicate with ourselves.
        throw 'Samskipti target window is same as present window' if window is @window

        # A new channel id.
        @channelId = channelId++
        
        # Method names to message handlers.
        @handlers = {}
        
        # Outgoing transactions.
        @outgoing = {}
        
        # Pending messages when not ready yet.
        @pending = []
                
        # Register channel with the router.
        router.register @window, @origin, @scope, @onMessage

        # Be ready when we are ready...
        @bind '__ready', @onReady

        # Say to the other window we are ready. Need to force the message.
        nextTick =>
            @postMessage {
                'method': @scopeMethod('__ready')
                'params': 'ping'
            }, yes

    # On an incoming message.
    onMessage: (origin, method, message) =>
        switch
            # This is a message with a handler.
            when message.id and method and @handlers[method]
                # Try getting a response by running the handler.
                try
                    result = @handlers[method].apply null, [ message.params ]
                    # We are done, no problems.
                    @postMessage { 'id': message.id, result }
                
                # Problems with running the handler.
                catch e
                    error = 'runtime_error' ; message = null
                    
                    # Parse the error.
                    switch
                        when _.isString e
                            message = e
                        
                        when _.isArray e
                            [ error, message ] = e

                        when _.isObject e
                            if _.isString e.error
                                error = e.error
                                
                                switch
                                    when not e.message
                                        message = ''
                                    when _.isString e.message
                                        message = e.message
                                    else
                                        e = e.message
                    
                    # Try stringifying.
                    unless message
                        try
                            message = JSON.stringify e
                        catch e2
                            message = do e.toString
                    
                    # Execute the error callback.
                    @postMessage { 'id': message.id, error, message }
            
            # Only message id.
            when message.id
                unless @outgoing[message.id]
                    @log "ignoring invalid response: #{message.id}"
                else
                    { error, message, id, result } = message
                    # Has error happened?
                    if error
                        @outgoing[id].error(error, message) if @outgoing[id].error
                    # Call success handler.
                    else
                        @outgoing[id].success(result or null)
                    
                    delete @outgoing[id]
                    delete router.transactions[id]
            
            # A notification.
            when method and @handlers[method]
                @handlers[method] { origin }, message.params

    # Ping the other window.
    onReady: (trans, type) =>
        @log 'ready msg received'
        throw 'received ready message while in ready state' if @ready
        
        @channelId += if type is "ping" then "-R" else "-L"
        
        @unbind "__ready" # now this handler isn't needed any more.
        @ready = yes
        @log "ready msg accepted."
        
        @notify {
            'method': "__ready"
            'params': "pong"
        } if type is "ping"

        # flush queue
        ( @postMessage do @pending.pop while @pending.length )

    # Post or enqueue messages to be posted.
    postMessage: (message, force=no) ->
        @log 'will post', message
        
        # Enqueue if we are not pinging or are not ready.
        return @pending.push(message) if not force and not @ready

        # Call the other window.
        @window.postMessage JSON.stringify(message), @origin

    # Prefix method name with its scope.
    scopeMethod: (method) -> [ @scope, method ].join('::')

    # Shall we log to the console?
    log: ->
        if @debug and window.console?.log?
            # Stringify args.
            args = _(arguments).toArray().reduce( (all, item) ->
                return all + ' ' + item if _.isString(item) # already a string?
                try
                    all + ' ' + JSON.stringify(item) # stringify then
                catch e
                    no # keep quiet
            )
            # We clearly shall...
            console.log "[#{@channelId}]", args

    # tries to unbind a bound message handler. returns false if not possible
    unbind: (method) ->
        if @handlers[method]
            throw ("can't delete method: #{method}") unless delete @handlers[method]
            return yes
        no

    # Bind a method to a handler.
    bind: (method, cb) ->
        throw '`method` must be string' if not method or not _.isString method
        throw 'callback missing' if not cb or not _.isFunction cb
        throw "method `#{method}` is already bound" if @handlers[method]
        
        @handlers[method] = cb
        
        @

    # Post a message after pruning fns from params.
    call: (message) ->
        # Validate.
        throw 'missing arguments to call function' unless message
        throw '`method` argument to call must be string' unless _.isString message.method
        throw '`success` callback missing from call' unless _.isFunction message.success
        throw '`error` callback missing from call' unless _.isFunction message.error

        # Build a 'request' message and send it.
        payload = {
            'id': currentTransactionId
            'method': @scopeMethod(message.method)
            'params': message.params
        }
        
        # Get the error and success callbacks.
        { error, success } = message

        # Insert message into outgoing bin.
        @outgoing[currentTransactionId] = { error, success }
        router.transactions[currentTransactionId] = @onMessage
        
        # Ready for the next transaction.
        currentTransactionId++

        # Post it.
        @postMessage payload

    notify: (m) ->
        throw "missing arguments to notify function" unless m
        throw "'method' argument to notify must be string" unless _.isString m.method
        
        # no need to go into any transaction table
        @postMessage {
            'method': @scopeMethod(m.method)
            'params': m.params
        }


    destroy: ->
        scope = if _.isString(@scope) then @scope else ''
        router.remove @window, @origin, scope

        switch
            when 'removeEventListener' of window
                window.removeEventListener "message", @onMessage, no

            when 'detachEvent' of window
                window.detachEvent "onmessage", @onMessage
        
        @ready = no
        @handlers = {}
        @outgoing = {}
        @origin = null
        @pending = []
        
        @log "channel destroyed"
        @channelId = ""

module.exports = Channel