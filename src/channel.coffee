_        = require 'lodash'
nextTick = require 'next-tick'

iFrame = require './iframe'

# Get the singleton of the router all channels use.
{ ChanID, FnID, router }  = require './router'
# App-wide constants.
constants = require './constants'

class Channel

    # Are we ready yet? When set to false we will block & queue outbound messages.
    ready: no

    # Specifies what the origin of the other `window` must be for the event to be  dispatched.
    #  Either use '*' (indicating no preference) or a URI.
    origin: '*'

    # Scope is prepended to message names. Windows of a single channel must agree upon scope.
    scope: 'testScope'

    # Create a new channel.
    constructor: (opts) ->
        opts ?= {}

        # Explode.
        { target, scope, template, debug } = opts

        # Shall we debug?
        @debug = yes if debug

        # A new channel id.
        { @id } = new ChanID()

        # Which scope to use?
        @scope = scope if scope

        # Parent or child.
        @window = if target then (@iframe = new iFrame({ @id, target, @scope, template })).el else window.parent

        # Make sure we do not communicate with ourselves.
        throw 'Samskipti target window is same as present window' if window is @window

        # Method names to message handlers.
        @handlers = {}
        
        # Pending messages when not ready yet.
        @pending = []

        # Register channel with the router.
        router.register @window, @origin, @scope, @onMessage

        # Be ready when we are ready...
        @on constants.ready, @onReady

        # Say to the other window we are ready. Need to force the message.
        nextTick =>
            @postMessage { 'method': @scopeMethod(constants.ready), 'params': 'ping' }, yes

    # Ping the other window.
    onReady: (type) =>
        throw 'received ready message while in ready state' if @ready
        
        # Set who is parent/child.
        @id += if type is 'ping' then ':A' else ':B'
        
        # No longer need to be called.
        @unbind constants.ready

        # Am ready.
        @ready = yes

        # Call back?
        @trigger constants.ready, 'pong' if type is 'ping'

        # Post enqueued messages.
        ( @postMessage do @pending.pop while @pending.length )

    # Interface to invoke a function on the other end.
    trigger: (method, opts) ->
        # Serialize the opts creating function callbacks when needed.
        params = (defunc = (obj) =>
            if _.isFunction obj
                # Get a new function id.
                { id } = new FnID()
                # Save the fn callback.
                @on id, obj
                # Return the handle.
                id
            else
                # Iterate over it.
                switch
                    # An array.
                    when _.isArray obj
                        _.collect obj, defunc
                    # Object and not an array.
                    when _.isObject obj
                        _.transform obj, (result, val, key) -> result[key] = defunc val
                    # Primitive.
                    else obj
        ) opts

        @postMessage { 'method': @scopeMethod(method), params }

    # Post or enqueue messages to be posted.
    postMessage: (message, force=no) ->
        # Enqueue if we are not pinging or are not ready.
        return @pending.push(message) if not force and not @ready

        # How to identify our messages?
        message[constants.postmessage] = yes

        # Call the other window.
        @window.postMessage JSON.stringify(message), @origin

    # On an incoming message.
    onMessage: (origin, method, params) =>
        # Form function callbacks on our end from passed params.
        params = (makefunc = (obj) =>
            # Iterate over it.
            switch
                # An array.
                when _.isArray obj
                    _.collect obj, makefunc
                # Object and not an array.
                when _.isObject obj
                    _.transform obj, (result, val, key) -> result[key] = makefunc val
                # Matching function pattern.
                when _.isString(obj) and obj.match(constants.function)
                    # When we get called...
                    =>
                        # Send a message to the other end invoking a callback function.
                        @trigger obj, arguments
                
                # Primitive.
                else obj
        ) params

        # Invoke the handler.
        if handler = @handlers[method]
            # Does it have a function prefix?
            if method.match(constants.function)
                # Need to apply params.
                handler.apply null, _.toArray(params)
            else
                handler params

    # Prefix method name with its scope.
    scopeMethod: (method) ->
        [ @scope, method ].join('::')

    # Register a method handler. One window saying what to do on receiving msg.
    on: (method, cb) ->
        throw '`method` must be string' if not method or not _.isString method
        throw 'callback missing' if not cb or not _.isFunction cb
        throw "method `#{method}` is already bound" if @handlers[method]
        
        @handlers[method] = cb
        
        @

    # Unregister a method handler. Primarily used internally.
    unbind: (method) ->
        delete @handlers[method]

module.exports = Channel