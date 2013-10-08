_ = require 'lodash'

# Maintain a routing table.
class Router

    # Routing table from origins to scopes, to message handlers.
    table: {}

    # No two outstanding outbound messages may have the same id, period.    Given that, a single table
    # mapping "transaction ids" to message handlers, allows efficient routing of Callback, Error, and
    # Response messages.    Entries are added to this table when requests are sent, and removed when
    # responses are received.
    transactions: {}

    # add a channel to router table, throwing if a dup exists
    register: (win, origin, scope='', handler) ->
        hasWin = (arr) ->
            ( return yes for x in arr when x.win is win )
            no

        # does she exist?
        exists = no
        
        if origin is "*"    
            # we must check all other origins, sadly.
            for k of @table when _.has(@table, k) and k isnt '*'
                if _.isObject @table[k][scope]
                    break if exists = hasWin @table[k][scope]
        
        else
            # we must check only '*'
            if @table["*"] and @table["*"][scope]
                exists = hasWin @table["*"][scope]

            if not exists and @table[origin] and @table[origin][scope]
                exists = hasWin @table[origin][scope]

        throw "A channel is already bound to the same window which overlaps with origin '#{origin}' and has scope '#{scope}'" if exists
        
        @table[origin] = {} unless _.isObject @table[origin]
        @table[origin][scope] = [] unless _.isObject @table[origin][scope]
        @table[origin][scope].push { win, handler }

    # Remove a channel.
    remove: (win, origin, scope) ->
        @table[origin][scope] = ( x for x in @table[origin][scope] when x.win is win )
        delete @table[origin][scope] unless @table[origin][scope].length

    # class singleton onMessage handler
    # this function is registered once and all incoming messages route through here.    This
    # arrangement allows certain efficiencies, message data is only parsed once and dispatch
    # is more efficient, especially for large numbers of simultaneous channels.
    onMessage: (e) =>
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
        # route using table
        switch
            when _.isString meth
                delivered = no
                if @table[o] and @table[o][s]
                    for j in [0...@table[o][s]] when @table[o][s][j].win is w
                        @table[o][s][j].handler(o, meth, m)
                        delivered = yes
                        break

                if not delivered and @table["*"] and @table["*"][s]
                    for j in @table["*"][s] when j.win is w
                        j.handler o, meth, m
                        break
        
            # otherwise it must have an id (or be poorly formed
            when i
                router.transactions[i](o, meth, m) if router.transactions[i]

# Browser capabilities check
throw ('Samskipti cannot run in this browser, no postMessage') unless 'postMessage' of window

# Transaction id.
transaction = 1
# Channel id.
channelId = 0

# Everybody use this one.
router = new Router()

# Attach postMessage listeners.
switch
    when 'addEventListener' of window
        window.addEventListener 'message', router.onMessage, no
    
    when 'attachEvent' of window
        window.attachEvent 'onmessage', router.onMessage

# All for one.
module.exports = { transaction, channelId, router }