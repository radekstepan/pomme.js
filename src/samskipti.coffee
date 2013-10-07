_        = require 'lodash'
nextTick = require 'next-tick'
  
# Transaction id.
s_curTranId = 1
# Channel id.
chanId = 0

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
        ( return yes for x in arr when x.win is win )
        no

    # does she exist?
    exists = no
    
    if origin is "*"    
        # we must check all other origins, sadly.
        for k of s_boundChans when _.has(s_boundChans, k) and k isnt '*'
            if _.isObject s_boundChans[k][scope]
                break if exists = hasWin s_boundChans[k][scope]
    
    else
        # we must check only '*'
        if s_boundChans["*"] and s_boundChans["*"][scope]
            exists = hasWin s_boundChans["*"][scope]

        if not exists and s_boundChans[origin] and s_boundChans[origin][scope]
            exists = hasWin s_boundChans[origin][scope]

    throw "A channel is already bound to the same window which overlaps with origin '#{origin}' and has scope '#{scope}'" if exists
    
    s_boundChans[origin] = {} unless _.isObject s_boundChans[origin]
    s_boundChans[origin][scope] = [] unless _.isObject s_boundChans[origin][scope]
    s_boundChans[origin][scope].push { win, handler }

s_removeBoundChan = (win, origin, scope) ->
    s_boundChans[origin][scope] = ( x for x in s_boundChans[origin][scope] when x.win is win )
    delete s_boundChans[origin][scope] unless s_boundChans[origin][scope].length

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
        throw "malformed" if m is null or not _.isObject(m)
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
            [ s, meth ] = ar
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
    switch
        when _.isString meth
            delivered = no
            if s_boundChans[o] and s_boundChans[o][s]
                for j in [0...s_boundChans[o][s]] when s_boundChans[o][s][j].win is w
                    s_boundChans[o][s][j].handler(o, meth, m)
                    delivered = yes
                    break

            if not delivered and s_boundChans["*"] and s_boundChans["*"][s]
                for j in s_boundChans["*"][s] when j.win is w
                    j.handler o, meth, m
                    break
    
        # otherwise it must have an id (or be poorly formed
        when i
            s_transIds[i](o, meth, m) if s_transIds[i]


# Setup postMessage event listeners
switch
    when 'addEventListener' of window
        window.addEventListener('message', s_onMessage, no)
    
    when 'attachEvent' of window
        window.attachEvent('onmessage', s_onMessage)

class Samskipti

    # are we ready yet? when false we will block outbound messages.
    ready: no

    # a messaging channel is constructed from a root and an origin.
    constructor: (@cfg) ->
        
        # browser capabilities check
        throw ("jschannel cannot run this browser, no postMessage") unless 'postMessage' of window
        
        # basic argument validation 
        # the remote window with which we'll communicate
        throw ("Samskipti invoked without a proper object argument") unless _.isObject @cfg
        throw ("Samskipti called without a valid window argument") if not @cfg.window or not @cfg.window.postMessage
        throw ("Samskipti target window is same as present window") if window is @cfg.window
        
        # The 'scope' of messages. A scope string that is prepended to message names. local and remote endpoints
        #  of a single channel must agree upon scope. Scope may not contain double colons ('::').            
        if @cfg.scope
            throw "scope, when specified, must be a string" if typeof @cfg.scope isnt "string"
            throw "scope may not contain double colons: '::'" if @cfg.scope.split("::").length > 1
        
        # Specifies what the origin of otherWindow must be for the event to be
        #  dispatched, either as the literal string "*" (indicating no preference) or as a URI.
        @cfg.origin ?= '*'

        # private variables 
        # generate a random and pseudo unique id for this channel
        @chanId = chanId++
        
        # registrations: mapping method names to call objects
        @regTbl = {}            
        # current oustanding sent requests
        @outTbl = {}
        # current oustanding received requests
        @inTbl = {}
        @pendingQueue = []
        
        # if the client throws, we'll just let it bubble out
        # what can we do? Also, here we'll ignore return values
        
        # now register our bound channel for msg routing
        msg = if _.isString(@cfg.scope) then @cfg.scope else ''
        s_addBoundChan @cfg.window, @cfg.origin, msg, @onMessage

        @bind "__ready", @onReady
        
        nextTick =>
            @postMessage {
                'method': @scopeMethod("__ready")
                'params': "ping"
            }, true

    debug: (m) ->
        # A boolean value. If true and root.console.log is a function, then debug strings will
        #  be emitted to that function.
        if @cfg.debugOutput and window.console?.log?
            # try to stringify, if it doesn't work we'll let javascript's built in toString do its magic
            try
                m = JSON.stringify(m) unless _.isString(m)
            
            console.log "[#{@chanId}] #{m}"

    setTransactionTimeout: (transId, timeout, method) ->
        window.setTimeout ( ->
            if @outTbl[transId]
                # XXX: what if client code raises an exception here?
                msg = "timeout (#{timeout}ms) exceeded on method '#{method}'"
                @outTbl[transId].error "timeout_error", msg
                delete @outTbl[transId]
                delete s_transIds[transId]
        ), timeout

    onMessage: (origin, method, m) =>
        switch
            # if an observer was specified at allocation time, invoke it
            # A function that will be passed two arguments, an origin and a message.
            #  It will be passed these arguments immediately after they pass scope and
            #  origin checks, but before they are processed.
            when _.isFunction @cfg.gotMessageObserver
                # pass observer a clone of the object so that our
                # manipulations are not visible (i.e. method unscoping).
                # This is not particularly efficient, but then we expect
                # that message observers are primarily for debugging anyway.
                try
                    @cfg.gotMessageObserver origin, m
                catch e
                    @debug "gotMessageObserver() raised an exception: #{e.toString()}"
            
            # now, what type of message is this?
            when m.id and method
                # a request! do we have a registered handler for this request?
                if @regTbl[method]
                    transaction = new Transaction m.id, origin, (m.callbacks or []), @

                    try
                        # callback handling. we'll magically create functions inside the parameter list for each
                        # callback
                        if m.callbacks and _.isArray(m.callbacks) and not m.callbacks.length
                            obj = m.params
                            pathItems = path.split("/")
                            for path in m.callbacks
                                for cp in pathItems[...-1]
                                    obj[cp] = {} unless _.isObject obj[cp]
                                    obj = obj[cp]
                                
                                obj[pathItems[pathItems.length - 1]] = do ->
                                    cbName = path
                                    (params) ->
                                        transaction.invoke cbName, params
                        
                        resp = @regTbl[method](transaction, m.params)
                        transaction.complete(resp) unless transaction.completed
                    
                    catch e
                        # automagic handling of exceptions:
                        error = "runtime_error"
                        message = null
                        
                        # * if it's a string then it gets an error code of 'runtime_error' and string is the message
                        if _.isString e
                            message = e
                        
                        else if _.isObject e
                            # either an array or an object
                            # * if it's an array of length two, then array[0] is the code, array[1] is the error message
                            if _.isArray e
                                [ error, message ] = e
                            
                            # * if it's an object then we'll look form error and message parameters
                            else if _.isString e.error
                                error = e.error
                                switch
                                    when not e.message
                                        message = ""
                                    
                                    when _.isString e.message
                                        message = e.message
                                    
                                    # let the stringify/toString message give us a reasonable verbose error string
                                    else
                                        e = e.message
                        
                        # message is *still* null, let's try harder
                        if message is null
                            try
                                message = JSON.stringify(e)
                                # On MSIE8, this can result in 'out of memory', which leaves message undefined. 
                                message = do e.toString if _.isUndefined message
                            catch e2
                                message = do e.toString
                        
                        transaction.error error, message
            
            when m.id and m.callback
                if not @outTbl[m.id] or not @outTbl[m.id].callbacks or not @outTbl[m.id].callbacks[m.callback]
                    @debug "ignoring invalid callback, id: #{m.id} (#{m.callback})"
                else
                    # XXX: what if client code raises an exception here?
                    @outTbl[m.id].callbacks[m.callback] m.params
            
            when m.id
                unless @outTbl[m.id]
                    @debug "ignoring invalid response: #{m.id}"
                else
                    # XXX: what if client code raises an exception here?
                    { error, message, id, result } = m
                    # Has error happened?
                    if error
                        @outTbl[id].error error, message if @outTbl[id].error
                    # Call success handler.
                    else
                        @outTbl[id].success result or null
                    
                    delete @outTbl[id]
                    delete s_transIds[id]
            
            when method
                # tis a notification.
                if @regTbl[method]
                    # yep, there's a handler for that.
                    # transaction has only origin for notifications.
                    @regTbl[method] { origin }, m.params

    # scope method names based on cfg.scope specified when the Channel was instantiated
    scopeMethod: (m) -> [ @cfg.scope, m ].join("::") if _.isString(@cfg.scope) and @cfg.scope.length

    # a small wrapper around postmessage whose primary function is to handle the
    # case that clients start sending messages before the other end is "ready"
    postMessage: (msg, force) ->
        throw "postMessage called with null message" unless msg
        
        # delay posting if we're not ready yet.
        verb = if @ready then "post" else "queue"
        @debug "#{verb} message: #{JSON.stringify(msg)}"
        
        if not force and not @ready
            @pendingQueue.push msg
        else
            # A function that will be passed two arguments, an origin and a message.
            #  It will be passed these immediately before messages are posted.
            if _.isFunction @cfg.postMessageObserver
                try
                    @cfg.postMessageObserver @cfg.origin, msg
                catch e
                    @debug "postMessageObserver() raised an exception: #{e.toString()}"

            @cfg.window.postMessage JSON.stringify(msg), @cfg.origin

    onReady: (trans, type) =>
        @debug "ready msg received"
        throw "received ready message while in ready state. help!" if @ready
        @chanId += if type is "ping" then "-R" else "-L"
        
        @unbind "__ready" # now this handler isn't needed any more.
        @ready = yes
        @debug "ready msg accepted."
        
        @notify {
            'method': "__ready"
            'params': "pong"
        } if type is "ping"

        # flush queue
        ( @postMessage do @pendingQueue.pop while @pendingQueue.length )
        
        # invoke onReady observer if provided
        # A function that will be invoked when a channel becomes "ready", this occurs once
        #  both sides of the channel have been instantiated and an application level handshake
        #  is exchanged. the onReady function will be passed a single argument which is the
        #  channel object that was returned from build().
        @cfg.onReady @ if _.isFunction @cfg.onReady

    # tries to unbind a bound message handler. returns false if not possible
    unbind: (method) ->
        if @regTbl[method]
            throw ("can't delete method: #{method}") unless delete @regTbl[method]
            return yes
        no

    bind: (method, cb) ->
        throw "'method' argument to bind must be string" if not method or not _.isString method
        throw "callback missing from bind params" if not cb or not _.isFunction cb
        throw "method '#{method}' is already bound!" if @regTbl[method]
        @regTbl[method] = cb
        @

    call: (m) ->
        throw "missing arguments to call function" unless m
        throw "'method' argument to call must be string" unless _.isString m.method
        throw "'success' callback missing from call" unless _.isFunction m.success
        throw "'error' callback missing from call" unless _.isFunction m.error
        
        # now it's time to support the 'callback' feature of jschannel.    We'll traverse the argument
        # object and pick out all of the functions that were passed as arguments.
        callbacks = {}
        callbackNames = []
        seen = []

        pruneFunctions = (path, obj) ->
            throw "params cannot be a recursive data structure" if obj in seen
            seen.push obj
            
            if _.isObject obj
                for k of obj when _.has(obj, k)
                    np = path + (if path.length then "/" else "") + k
                    if _.isFunction obj[k]
                        callbacks[np] = obj[k]
                        callbackNames.push np
                        delete obj[k]
                    else pruneFunctions np, obj[k] if _.isObject obj[k]

        pruneFunctions "", m.params
        
        # build a 'request' message and send it
        msg = {
            'id': s_curTranId
            'method': @scopeMethod(m.method)
            'params': m.params
        }

        msg.callbacks = callbackNames if callbackNames.length
        
        # XXX: This function returns a timeout ID, but we don't do anything with it.
        # We might want to keep track of it so we can cancel it using clearTimeout()
        # when the transaction completes.
        setTransactionTimeout(s_curTranId, m.timeout, @scopeMethod(m.method)) if m.timeout
        
        # insert into the transaction table
        { error, success } = m
        @outTbl[s_curTranId] = { callbacks, error, success }

        s_transIds[s_curTranId] = @onMessage
        
        # increment current id
        s_curTranId++
        @postMessage msg

    notify: (m) ->
        throw "missing arguments to notify function" unless m
        throw "'method' argument to notify must be string" unless _.isString m.method
        
        # no need to go into any transaction table
        @postMessage {
            'method': @scopeMethod(m.method)
            'params': m.params
        }


    destroy: ->
        scope = if _.isString(@cfg.scope) then @cfg.scope else ''
        s_removeBoundChan @cfg.window, @cfg.origin, scope

        switch
            when 'removeEventListener' of window
                window.removeEventListener "message", @onMessage, no

            when 'detachEvent' of window
                window.detachEvent "onmessage", @onMessage
        
        @ready = no
        @regTbl = {}
        @inTbl = {}
        @outTbl = {}
        @cfg.origin = null
        @pendingQueue = []
        
        @debug "channel destroyed"
        @chanId = ""

class Transaction

    completed: no

    constructor: (@id, @origin, @callbacks, @channel) ->
        @channel.inTbl[@id] = {}
            
    invoke: (callback, params) =>
        # verify in table
        throw "attempting to invoke a callback of a nonexistent transaction: #{@id}" unless @channel.inTbl[@id]
        
        # verify that the callback name is valid
        if do ( -> ( return yes for cb in @callbacks when cb is callback ) )
            # send callback invocation
            @channel.postMessage { @id, params, callback }
        else
            throw "request supports no such callback '#{callback}'"

    error: (error, message) =>
        @completed = yes
        
        # verify in table
        throw "error called for nonexistent message: #{@id}" unless @channel.inTbl[@id]
        
        # remove transaction from table
        delete @channel.inTbl[@id]
        
        # send error
        @channel.postMessage { @id, error, message }

    complete: (result) =>
        @completed = yes
        
        # verify in table
        throw "complete called for nonexistent message: #{@id}" unless @channel.inTbl[@id]
        
        # remove transaction from table
        delete @channel.inTbl[@id]

        # send complete
        @channel.postMessage { @id, result }

module.exports = Samskipti