constants = require './constants'

# Maintain a routing table.
class Router

    # Routing table from origins to scopes, to message handlers.
    table: {}

    # A map of transaction ids to a channel onMessage handler.
    transactions: {}

    # Add a channel to routing table.
    register: (win, scope='', handler) ->
        @table[scope] ?= []

        for route in @table[scope] when route.win is win
            throw "a channel is already bound to the same window under `#{scope}`"
        
        # Register this origin & scope.
        @table[scope].push { win, handler }

    # Route a message.
    route: (event) =>
        data = null
        # Only accept "our" messages.
        try data = JSON.parse event.data

        # Well formed but not for our app.
        return unless _.isObject(data) and constants.postmessage in _.keys(data)

        scope = null ; method = null

        if _.isString(data.method)
            # Split on the first separator.
            [ scope, method ] = data.method.match(/^([^:]+)::(.+)$/)[1..2]
            # Unscoped?
            method = data.method unless scope and method

        if method and @table[scope]?
            # Find the route in our table.
            for route in @table[scope] when route.win is event.source
                # Trigger the handler.
                return route.handler method, data.params


# ID generators.
class ChanID
    
    _id: 0

    constructor: ->
        @id = ChanID::_id++

class FnID

    _id: 0

    constructor: ->
        @id = constants.function + FnID::_id++

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