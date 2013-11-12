iFrame  = require './iframe'
helpers = require './helpers'

# Get the singleton of the router all channels use.
{ ChanID, FnID, router }  = require './router'
# App-wide constants.
constants = require './constants'

class Channel

    # Are we ready yet? When set to false we will block & queue outbound messages.
    ready: no

    # Scope is prepended to message names. Windows of a single channel must agree upon scope.
    scope: 'testScope'

    # Create a new channel.
    constructor: (opts) ->
        opts ?= {}

        # Explode.
        { target, scope, template } = opts

        # A new channel id.
        { @id } = new ChanID()

        # Which scope to use?
        @scope = scope if scope

        throw 'only strings accepted for a scope' unless _.isString @scope

        switch
            # Parent; existing window.
            when _.isWindow target
                @window = target
            # Parrent; create iframe.
            when target
                @window = (@iframe = new iFrame({ @id, target, @scope, template })).el
            # Child; point to parent.
            else
                @window = window.parent
                @child = yes

        # Echo chamber not allowed.
        throw 'child and parent windows cannot be one and the same' if window is @window

        # Method names to message handlers.
        @handlers = {}
        
        # Pending messages when not ready yet.
        @pending = []

        # Register channel with the router.
        router.register @window, @scope, @onMessage
        
        # Be ready when we are ready...
        @on constants.ready, @onReady

        # By default add an eval listener in context of this class.
        @on 'eval', (code) =>
            eval.call @, code

        # Say to the other window we are ready. Need to force the message.
        helpers.nextTick =>
            @postMessage { 'method': @scopeMethod(constants.ready), 'params': [ 'ping' ] }, yes

    # Ping the other window.
    onReady: (type) =>
        return @error 'received ready message while in ready state' if @ready

        # Set who is parent/child.
        @id += [ ':B', ':A' ][+type is 'ping']
        
        # No longer need to be called.
        @unbind constants.ready

        # Am ready.
        @ready = yes

        # Call back?
        @trigger constants.ready, 'pong' if type is 'ping'

        # Post enqueued messages.
        ( @postMessage do @pending.pop while @pending.length )

    # Interface to invoke a function on the other end.
    trigger: (method, opts...) ->
        # Is this circular?
        try
            JSON.stringify opts
        catch e
            return @error 'cannot convert circular structure'

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

        @

    # Post or enqueue messages to be posted.
    postMessage: (message, force=no) ->
        # Sometimes we are already disposed.
        return if @disposed
        # Enqueue if we are not pinging or are not ready.
        return @pending.push(message) if not force and not @ready

        # How to identify our messages?
        message[constants.postmessage] = yes

        # Call the other window.
        @window.postMessage JSON.stringify(message), '*'

    # On an incoming message.
    onMessage: (method, params) =>
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
                        @trigger.apply @, [ obj ].concat _.toArray(arguments)
                
                # Primitive.
                else obj
        ) params

        # Skip if not present.
        return unless _.isFunction handler = @handlers[method]

        # Just making sure...
        params = [ params ] unless _.isArray(params)

        # Call.
        try
            handler.apply null, params
        catch err
            @error err

    # Prefix method name with its scope.
    scopeMethod: (method) ->
        [ @scope, method ].join('::')

    # Register a method handler. One window saying what to do on receiving msg.
    on: (method, cb) ->
        return if @disposed

        return @error '`method` must be string' if not method or not _.isString method
        return @error 'callback missing' if not cb or not _.isFunction cb
        return @error "`#{method}` is already bound" if @handlers[method]

        @handlers[method] = cb
        
        @

    # Unregister a method handler. Primarily used internally.
    unbind: (method) ->
        return @error "`#{method}` is not bound" unless method of @handlers
        delete @handlers[method]

    # Throw an error.
    error: (err) ->
        message = null
        
        # Parse the error.
        switch
            when _.isString err
                message = err
            when _.isArray err
                message = err[1]
            when _.isObject(err) and _.isString(err.message)
                message = err.message

        unless message
            try
                message = JSON.stringify err
            catch
                message = do err.toString

        # Are we a child?
        if @child
            # Do we have an explicitly set listener?
            if _.isFunction @handlers.error
                # Trigger it then.
                @handlers.error message
            else
                # Send it to the parent then.
                # If `error` is not listening there, we are still silent.
                @trigger('error', message)
        else
            # Be silent by default.
            @handlers.error ?= (err) ->
            # Trigger it.
            @handlers.error message

    # Kill me...
    dispose: ->
        return if @disposed
        @disposed = yes
        # Has iframe?
        do @iframe?.dispose
        # Any listeners? Only keep error the error one.
        ( @unbind key for key, val of @handlers when key isnt 'error' )
        # No moar change.
        Object.freeze? @handlers
        Object.freeze? @

module.exports = Channel

# Extend lodash.
_.mixin do ->
    'isWindow': (obj) ->
        switch
            when not _.isObject obj
                no
            else
                obj.window is obj
    # Only works on Objects unlike its Lodash counterpart.
    'transform': (obj, cb) ->
        ( cb(obj, val, key) for key, val of obj )
        obj