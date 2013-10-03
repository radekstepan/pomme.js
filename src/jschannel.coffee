root = @
#
# * js_channel is a very lightweight abstraction on top of
# * postMessage which defines message formats and semantics
# * to support interactions more rich than just message passing
# * js_channel supports:
# *    + query/response - traditional rpc
# *    + query/update/response - incremental async return of results
# *        to a query
# *    + notifications - fire and forget
# *    + error handling
# *
# * js_channel is based heavily on json-rpc, but is focused at the
# * problem of inter-iframe RPC.
# *
# * Message types:
# *    There are 5 types of messages that can flow over this channel,
# *    and you may determine what type of message an object is by
# *    examining its parameters:
# *    1. Requests
# *        + integer id
# *        + string method
# *        + (optional) any params
# *    2. Callback Invocations (or just "Callbacks")
# *        + integer id
# *        + string callback
# *        + (optional) params
# *    3. Error Responses (or just "Errors)
# *        + integer id
# *        + string error
# *        + (optional) string message
# *    4. Responses
# *        + integer id
# *        + (optional) any result
# *    5. Notifications
# *        + string method
# *        + (optional) any params
# 
root.Channel = do ->
    
    # current transaction id, start out at a random *odd* number between 1 and a million
    # There is one current transaction counter id per page, and it's shared between
    # channel instances.    That means of all messages posted from a single javascript
    # evaluation context, we'll never have two with the same id.
    s_curTranId = Math.floor do Math.random * 1000001

    # no two bound channels in the same javascript evaluation context may have the same origin, scope, and root.
    # futher if two bound channels have the same root and scope, they may not have *overlapping* origins
    # (either one or both support '*').    This restriction allows a single onMessage handler to efficiently
    # route messages based on origin and scope.    The s_boundChans maps origins to scopes, to message
    # handlers.    Request and Notification messages are routed using this table.
    # Finally, channels are inserted into this table when built, and removed when destroyed.
    s_boundChans = {}
    
    # add a channel to s_boundChans, throwing if a dup exists
    s_addBoundChan = (win, origin, scope, handler) ->        
        hasWin = (arr) ->
            ( return true for x in arr when x.win is win )
            false

        # does she exist?
        exists = false
        
        if origin is "*"    
            # we must check all other origins, sadly.
            for k of s_boundChans
                continue unless s_boundChans.hasOwnProperty(k)
                continue if k is "*"
                if typeof s_boundChans[k][scope] is "object"
                    exists = hasWin s_boundChans[k][scope]
                    break if exists
        
        else
            # we must check only '*'
            if s_boundChans["*"] and s_boundChans["*"][scope]
                exists = hasWin s_boundChans["*"][scope]

            if not exists and s_boundChans[origin] and s_boundChans[origin][scope]
                exists = hasWin s_boundChans[origin][scope]

        throw "A channel is already bound to the same root which overlaps with origin '#{origin}' and has scope '#{scope}'" if exists
        
        s_boundChans[origin] = {} unless typeof s_boundChans[origin] is "object"
        s_boundChans[origin][scope] = [] unless typeof s_boundChans[origin][scope] is "object"
        s_boundChans[origin][scope].push { win, handler }

    s_removeBoundChan = (win, origin, scope) ->
        s_boundChans[origin][scope] = ( x for x in s_boundChans[origin][scope] when x.win is win )
        delete s_boundChans[origin][scope] unless s_boundChans[origin][scope].length
    
    s_isArray = (obj) ->
        obj.constructor.toString().indexOf("Array") isnt -1 unless Array.isArray
    
    # No two outstanding outbound messages may have the same id, period.    Given that, a single table
    # mapping "transaction ids" to message handlers, allows efficient routing of Callback, Error, and
    # Response messages.    Entries are added to this table when requests are sent, and removed when
    # responses are received.
    s_transIds = {}
    
    # class singleton onMessage handler
    # this function is registered once and all incoming messages route through here.    This
    # arrangement allows certain efficiencies, message data is only parsed once and dispatch
    # is more efficient, especially for large numbers of simultaneous channels.
    s_onMessage = (e) ->
        try
            m = JSON.parse(e.data)
            throw "malformed" if typeof m isnt "object" or m is null
        catch e
            # just ignore any posted messages that do not consist of valid JSON
            return
        
        w = e.source
        o = e.origin
        s = undefined
        i = undefined
        meth = undefined

        if typeof m.method is "string"
            ar = m.method.split("::")
            if ar.length is 2
                [ s, meth ] = ar
            else
                meth = m.method
        
        i = m.id if m.id
        
        # w is message source root
        # o is message origin
        # m is parsed message
        # s is message scope
        # i is message id (or undefined)
        # meth is unscoped method name
        # ^^ based on these factors we can route the message
        
        # if it has a method it's either a notification or a request,
        # route using s_boundChans
        if typeof meth is "string"
            delivered = no
            if s_boundChans[o] and s_boundChans[o][s]
                for j in [0...s_boundChans[o][s]] when s_boundChans[o][s][j].win is w
                    s_boundChans[o][s][j].handler(o, meth, m)
                    delivered = yes
                    break

            if not delivered and s_boundChans["*"] and s_boundChans["*"][s]
                for j in [0...s_boundChans["*"][s].length] when s_boundChans['*'][s][j].win is w
                    s_boundChans["*"][s][j].handler o, meth, m
                    break
        
        # otherwise it must have an id (or be poorly formed
        else if i
            s_transIds[i](o, meth, m) if s_transIds[i]

    
    # Setup postMessage event listeners
    switch
        when 'addEventListener' of root
            root.addEventListener('message', s_onMessage, no)
        when 'attachEvent' of root
            root.attachEvent('onmessage', s_onMessage)
    
    # a messaging channel is constructed from a root and an origin.
    #         * the channel will assert that all messages received over the
    #         * channel match the origin
    #         *
    #         * Arguments to Channel.build(cfg):
    #         *
    #         *     cfg.window - the remote window with which we'll communicate
    #         *     cfg.origin - the expected origin of the remote root, may be '*'
    #         *                                which matches any origin
    #         *     cfg.scope  - the 'scope' of messages.    a scope string that is
    #         *                                prepended to message names.    local and remote endpoints
    #         *                                of a single channel must agree upon scope. Scope may
    #         *                                not contain double colons ('::').
    #         *     cfg.debugOutput - A boolean value.    If true and root.console.log is
    #         *                                a function, then debug strings will be emitted to that
    #         *                                function.
    #         *     cfg.debugOutput - A boolean value.    If true and root.console.log is
    #         *                                a function, then debug strings will be emitted to that
    #         *                                function.
    #         *     cfg.postMessageObserver - A function that will be passed two arguments,
    #         *                                an origin and a message.    It will be passed these immediately
    #         *                                before messages are posted.
    #         *     cfg.gotMessageObserver - A function that will be passed two arguments,
    #         *                                an origin and a message.    It will be passed these arguments
    #         *                                immediately after they pass scope and origin checks, but before
    #         *                                they are processed.
    #         *     cfg.onReady - A function that will be invoked when a channel becomes "ready",
    #         *                                this occurs once both sides of the channel have been
    #         *                                instantiated and an application level handshake is exchanged.
    #         *                                the onReady function will be passed a single argument which is
    #         *                                the channel object that was returned from build().
    #         
    return {
        'build': (cfg) ->
            debug = (m) ->
                if cfg.debugOutput and root.console?.log?
                    # try to stringify, if it doesn't work we'll let javascript's built in toString do its magic
                    try
                        m = JSON.stringify(m) if typeof m isnt "string"
                    
                    console.log "[#{chanId}] #{m}"
            
            # browser capabilities check
            # throw ("jschannel cannot run this browser, no postMessage") unless 'postMessage' of root
            # throw ("jschannel cannot run this browser, no JSON parsing/serialization") if not root.JSON or not root.JSON.stringify or not root.JSON.parse
            
            # basic argument validation 
            # throw ("Channel build invoked without a proper object argument") unless typeof cfg is "object"
            # throw ("Channel.build() called without a valid root argument") if not cfg.window or not cfg.window.postMessage
            
            # we'd have to do a little more work to be able to run multiple channels that intercommunicate the same
            #                         * root...    Not sure if we care to support that 
            throw ("target root is same as present root -- not allowed") if root is cfg.window
            
            # let's require that the client specify an origin. if we just assume '*' we'll be
            # propagating unsafe practices. that would be lame.
            validOrigin = false
            if typeof cfg.origin is "string"
                oMatch = undefined
                if cfg.origin is "*"
                    validOrigin = yes
                # allow valid domains under http and https.    Also, trim paths off otherwise valid origins.
                else if null isnt (oMatch = cfg.origin.match(/^https?:\/\/(?:[-a-zA-Z0-9_\.])+(?::\d+)?/))
                    cfg.origin = oMatch[0].toLowerCase()
                    validOrigin = yes
            
            throw ("Channel.build() called with an invalid origin") unless validOrigin
            
            if cfg.scope
                throw "scope, when specified, must be a string" if typeof cfg.scope isnt "string"
                throw "scope may not contain double colons: '::'" if cfg.scope.split("::").length > 1
            
            # private variables 
            # generate a random and psuedo unique id for this channel
            chanId = do ->
                text = ""
                alpha = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                ( text += alpha.charAt(Math.floor(Math.random() * alpha.length)) for i in [0...5] )
                text
            
            # registrations: mapping method names to call objects
            regTbl = {}            
            # current oustanding sent requests
            outTbl = {}
            # current oustanding received requests
            inTbl = {}
            # are we ready yet? when false we will block outbound messages.
            ready = no
            pendingQueue = []
            
            createTransaction = (id, origin, callbacks) ->
                shouldDelayReturn = no
                completed = no
                
                return {
                    'origin': origin
                    'invoke': (callback, params) ->
                        # verify in table
                        throw "attempting to invoke a callback of a nonexistent transaction: #{id}" unless inTbl[id]
                        # verify that the callback name is valid
                        valid = no
                        
                        for cb in callbacks when cb is callback
                            valid = yes
                            break

                        throw "request supports no such callback '#{callback}'" unless valid
                        
                        # send callback invocation
                        postMessage { id, params, callback }


                    'error': (error, message) ->
                        completed = yes
                        
                        # verify in table
                        throw "error called for nonexistent message: #{id}" unless inTbl[id]
                        
                        # remove transaction from table
                        delete inTbl[id]
                        
                        # send error
                        postMessage { id, error, message }


                    'complete': (v) ->
                        completed = yes
                        
                        # verify in table
                        throw "complete called for nonexistent message: #{id}" unless inTbl[id]
                        
                        # remove transaction from table
                        delete inTbl[id]

                        # send complete
                        postMessage {
                            id
                            'result': v
                        }


                    'delayReturn': (delay) ->
                        shouldDelayReturn = (delay is yes) if typeof delay is "boolean"
                        shouldDelayReturn

                    'completed': ->
                        completed
                }

            setTransactionTimeout = (transId, timeout, method) ->
                root.setTimeout ( ->
                    if outTbl[transId]
                        # XXX: what if client code raises an exception here?
                        msg = "timeout (#{timeout}ms) exceeded on method '#{method}'"
                        (1
                        outTbl[transId].error
                        ) "timeout_error", msg
                        
                        delete outTbl[transId]
                        delete s_transIds[transId]
                ), timeout

            onMessage = (origin, method, m) ->
                # if an observer was specified at allocation time, invoke it
                if typeof cfg.gotMessageObserver is "function"
                    # pass observer a clone of the object so that our
                    # manipulations are not visible (i.e. method unscoping).
                    # This is not particularly efficient, but then we expect
                    # that message observers are primarily for debugging anyway.
                    try
                        cfg.gotMessageObserver origin, m
                    catch e
                        debug "gotMessageObserver() raised an exception: #{e.toString()}"
                
                # now, what type of message is this?
                if m.id and method
                    # a request! do we have a registered handler for this request?
                    if regTbl[method]
                        trans = createTransaction(m.id, origin, (if m.callbacks then m.callbacks else []))
                        inTbl[m.id] = {}
                        
                        try
                            # callback handling. we'll magically create functions inside the parameter list for each
                            # callback
                            if m.callbacks and s_isArray(m.callbacks) and not m.callbacks.length
                                obj = m.params
                                pathItems = path.split("/")
                                for path in m.callbacks
                                    for cp in pathItems[...-1]
                                        obj[cp] = {} if typeof obj[cp] isnt "object"
                                        obj = obj[cp]
                                    
                                    obj[pathItems[pathItems.length - 1]] = do ->
                                        cbName = path
                                        (params) ->
                                            trans.invoke cbName, params
                            
                            resp = regTbl[method](trans, m.params)
                            trans.complete resp if not do trans.delayReturn and not do trans.completed
                        
                        catch e
                            # automagic handling of exceptions:
                            error = "runtime_error"
                            message = null
                            
                            # * if it's a string then it gets an error code of 'runtime_error' and string is the message
                            if typeof e is "string"
                                message = e
                            else if typeof e is "object"
                                # either an array or an object
                                # * if it's an array of length two, then array[0] is the code, array[1] is the error message
                                if e and s_isArray(e) and e.length is 2
                                    [ error, message ] = e
                                
                                # * if it's an object then we'll look form error and message parameters
                                else if typeof e.error is "string"
                                    error = e.error
                                    unless e.message
                                        message = ""
                                    else if typeof e.message is "string"
                                        message = e.message
                                    # let the stringify/toString message give us a reasonable verbose error string
                                    else
                                        e = e.message
                            
                            # message is *still* null, let's try harder
                            if message is null
                                try
                                    message = JSON.stringify(e)
                                    # On MSIE8, this can result in 'out of memory', which leaves message undefined. 
                                    message = do e.toString if typeof (message) is "undefined"
                                catch e2
                                    message = do e.toString
                            
                            trans.error error, message
                
                else if m.id and m.callback
                    if not outTbl[m.id] or not outTbl[m.id].callbacks or not outTbl[m.id].callbacks[m.callback]
                        debug "ignoring invalid callback, id: #{m.id} (#{m.callback})"
                    else
                        # XXX: what if client code raises an exception here?
                        outTbl[m.id].callbacks[m.callback] m.params
                
                else if m.id
                    unless outTbl[m.id]
                        debug "ignoring invalid response: #{m.id}"
                    else
                        # XXX: what if client code raises an exception here?
                        if m.error
                            (1
                            outTbl[m.id].error
                            ) m.error, m.message
                        else
                            if m.result
                                (1
                                outTbl[m.id].success
                                ) m.result
                            else
                                (1
                                outTbl[m.id].success
                                )()
                        
                        delete outTbl[m.id]
                        delete s_transIds[m.id]
                
                else if method
                    # tis a notification.
                    if regTbl[method]
                        # yep, there's a handler for that.
                        # transaction has only origin for notifications.
                        regTbl[method] { origin }, m.params

            
            # if the client throws, we'll just let it bubble out
            # what can we do? Also, here we'll ignore return values
            
            # now register our bound channel for msg routing
            msg = if typeof cfg.scope is "string" then cfg.scope else ''
            s_addBoundChan cfg.window, cfg.origin, msg, onMessage
            
            # scope method names based on cfg.scope specified when the Channel was instantiated
            scopeMethod = (m) ->
                m = [cfg.scope, m].join("::") if typeof cfg.scope is "string" and cfg.scope.length
                m
            
            # a small wrapper around postmessage whose primary function is to handle the
            # case that clients start sending messages before the other end is "ready"
            postMessage = (msg, force) ->
                throw "postMessage called with null message" unless msg
                
                # delay posting if we're not ready yet.
                verb = if ready then "post" else "queue"
                debug "#{verb} message: #{JSON.stringify(msg)}"
                
                if not force and not ready
                    pendingQueue.push msg
                else
                    if typeof cfg.postMessageObserver is "function"
                        try
                            cfg.postMessageObserver cfg.origin, msg
                        catch e
                            debug "postMessageObserver() raised an exception: #{e.toString()}"

                    cfg.window.postMessage JSON.stringify(msg), cfg.origin

            onReady = (trans, type) ->
                debug "ready msg received"
                throw "received ready message while in ready state. help!" if ready
                chanId += if type is "ping" then "-R" else "-L"
                
                obj.unbind "__ready" # now this handler isn't needed any more.
                ready = yes
                debug "ready msg accepted."
                
                if type is "ping"
                    obj.notify
                        'method': "__ready"
                        'params': "pong"

                # flush queue
                postMessage do pendingQueue.pop while pendingQueue.length
                
                # invoke onReady observer if provided
                cfg.onReady obj if typeof cfg.onReady is "function"

            obj = {
                # tries to unbind a bound message handler. returns false if not possible
                'unbind': (method) ->
                    if regTbl[method]
                        throw ("can't delete method: #{method}") unless delete regTbl[method]
                        return yes
                    no

                'bind': (method, cb) ->
                    throw "'method' argument to bind must be string" if not method or typeof method isnt "string"
                    throw "callback missing from bind params" if not cb or typeof cb isnt "function"
                    throw "method '#{method}' is already bound!" if regTbl[method]
                    regTbl[method] = cb
                    @

                'call': (m) ->
                    throw "missing arguments to call function" unless m
                    throw "'method' argument to call must be string" if not m.method or typeof m.method isnt "string"
                    throw "'success' callback missing from call" if not m.success or typeof m.success isnt "function"
                    
                    # now it's time to support the 'callback' feature of jschannel.    We'll traverse the argument
                    # object and pick out all of the functions that were passed as arguments.
                    callbacks = {}
                    callbackNames = []
                    seen = []

                    pruneFunctions = (path, obj) ->
                        throw "params cannot be a recursive data structure" if obj in seen
                        seen.push obj
                        
                        if typeof obj is "object"
                            for k of obj when obj.hasOwnProperty(k)
                                np = path + (if path.length then "/" else "") + k
                                if typeof obj[k] is "function"
                                    callbacks[np] = obj[k]
                                    callbackNames.push np
                                    delete obj[k]
                                else pruneFunctions np, obj[k] if typeof obj[k] is "object"

                    pruneFunctions "", m.params
                    
                    # build a 'request' message and send it
                    msg =
                        'id': s_curTranId
                        'method': scopeMethod(m.method)
                        'params': m.params

                    msg.callbacks = callbackNames if callbackNames.length
                    
                    # XXX: This function returns a timeout ID, but we don't do anything with it.
                    # We might want to keep track of it so we can cancel it using clearTimeout()
                    # when the transaction completes.
                    setTransactionTimeout s_curTranId, m.timeout, scopeMethod(m.method) if m.timeout
                    
                    # insert into the transaction table
                    { error, success } = m
                    outTbl[s_curTranId] = { callbacks, error, success }

                    s_transIds[s_curTranId] = onMessage
                    
                    # increment current id
                    s_curTranId++
                    postMessage msg

                'notify': (m) ->
                    throw "missing arguments to notify function" unless m
                    throw "'method' argument to notify must be string" if not m.method or typeof m.method isnt "string"
                    
                    # no need to go into any transaction table
                    postMessage {
                        'method': scopeMethod(m.method)
                        'params': m.params
                    }


                'destroy': ->
                    scope = if typeof cfg.scope is 'string' then cfg.scope else ''
                    s_removeBoundChan cfg.window, cfg.origin, scope
                    if 'removeEventListener' of root
                        root.removeEventListener "message", onMessage, no
                    else root.detachEvent "onmessage", onMessage if root.detachEvent
                    
                    ready = no
                    regTbl = {}
                    inTbl = {}
                    outTbl = {}
                    cfg.origin = null
                    pendingQueue = []
                    
                    debug "channel destroyed"
                    chanId = ""
            }

            obj.bind "__ready", onReady
            # Should be a process.nextTick
            setTimeout (->
                postMessage {
                    'method': scopeMethod("__ready")
                    'params': "ping"
                }, true
            ), 0
            obj
    }