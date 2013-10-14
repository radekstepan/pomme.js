_ = require 'lodash'

constants = require './constants'

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
    route: (event) =>
        data = null
        # Only accept "our" messages. What if other libs use JSON too?
        try data = JSON.parse event.data

        # Well formed but not for our app.
        return unless _.isObject(data) and constants.postmessage in _.keys(data)

        scope = null ; method = null

        if _.isString(data.method)
            # Split on the first separator.
            [ scope, method ] = data.method.match(/^([^:]+)::(.+)$/)[1..2]
            # Unscoped?
            method = data.method unless scope and method
        
        # A URI/whatever based origin.
        if method
            for origin in [ event.origin, '*' ] when @table[origin]?[scope]?
                if route = _.find(@table[origin][scope], { 'win': event.source })
                    return route.handler(origin, method, data.params)


# ID generators.
class ChanID
    
    _id: 0

    constructor: -> @id = ChanID::_id++

class FnID

    _id: 0

    constructor: -> @id = constants.function + FnID::_id++

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
module.exports = { ChanID, FnID, router }