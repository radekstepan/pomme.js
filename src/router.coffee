_ = require 'lodash'

# Maintain a routing table.
class Router

    # Routing table from origins to scopes, to message handlers.
    table: {}

    # A map of transaction ids to a channel onMessage handler.
    transactions: {}

    # Add a channel to routing table.
    register: (win, origin, scope='', handler) ->
        # does she exist?
        exists = no
        if origin is '*'
            # we must check all other origins, sadly.
            for key, value of @table when _.has(@table, key) and key isnt '*'
                break if _.find(value[scope], { win })
        
        else
            unless exists = @table['*']?[scope]? and hasWin _.find(@table['*'][scope], { win })
                exists = _.find(@table[origin][scope], { win }) if @table[origin]?[scope]?

        throw "A channel is already bound to the same window which overlaps with origin `#{origin}` and has scope `#{scope}`" if exists
        
        # Register this origin & scope.
        @table[origin] ?= {}
        @table[origin][scope] ?= []
        @table[origin][scope].push { win, handler }

    # Remove a channel.
    remove: (win, origin, scope) ->
        @table[origin][scope] = _.find @table[origin][scope], { win }
        delete @table[origin][scope] unless @table[origin][scope].length

    # Route a message.
    route: (e) =>
        # Only accept "our" messages. What if other libs use JSON too?
        try
            m = JSON.parse e.data
            throw 'malformed' unless _.isObject m
        catch e
            return

        scope = null ; method = null

        if _.isString(m.method)
            [ scope, method ] = m.method.split('::')
            method = m.method unless scope and method

        switch
            # Has a method.
            when _.isString method
                # A URI/whatever based origin.
                for origin in [ e.origin, '*' ] when @table[origin]?[scope]?
                    if route = _.find(@table[origin][scope], { 'win': e.source })
                        return route.handler(origin, method, m)
        
            # Has message id.
            when m.id
                router.transactions[m.id]?(e.origin, method, m)


# Wrappers around transaction & channel ids.
class TransID
    
    _id: 1
    
    constructor: -> @id = TransID::_id++

class ChanID
    
    _id: 0

    constructor: -> @id = ChanID::_id++


# Browser capabilities check
throw ('Samskipti cannot run in this browser, no postMessage') unless 'postMessage' of window


# Everybody use this one.
router = new Router()

# Attach postMessage listeners.
switch
    when 'addEventListener' of window
        window.addEventListener 'message', router.route, no
    
    when 'attachEvent' of window
        window.attachEvent 'onmessage', router.route

# All for one.
module.exports = { TransID, ChanID, router }