constants = require './constants'

_ = require 'lodash'

class iFrame

    constructor: ({ id, target, scope, template }) ->
        # Good selector?
        try document.querySelector target
        catch
            return @error 'target selector not found'

        name = constants.iframe + id or + new Date

        # Create the iframe.
        @self = document.createElement 'iframe'
        @self.name = name
        document.querySelector(target).appendChild @self

        # Use a custom template or go spec one?
        template ?= require './template'

        return @error 'template is not a function' unless _.isFunction template

        # Pass it scope.
        return @error 'template did not return a string' unless _.isString html = template { scope }

        # Write custom content.
        do @self.contentWindow.document.open
        @self.contentWindow.document.write html
        do @self.contentWindow.document.close

        # Refer to the iframe's document.
        @el = window.frames[name]

    error: (message) ->
        do @dispose
        throw message

    dispose: ->
        # Destroy DOM.
        do @self?.remove
        # No moar change.
        Object.freeze? @

module.exports = iFrame