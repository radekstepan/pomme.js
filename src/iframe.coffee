constants = require './constants'

class Iframe

    constructor: ({ id, target, scope, template }) ->
        # Good selector?
        try
            document.querySelector target
        catch
            return @error 'target selector not found'

        name = constants.iframe + id or + new Date

        # Create the iframe.
        @node = document.createElement 'iframe'
        @node.name = name
        document.querySelector(target).appendChild @node

        unless _.isFunction template
            return @error 'template is not a function'

        # Pass it scope.
        unless _.isString html = template { scope }
            return @error 'template did not return a string'

        # Write custom content.
        do @node.contentWindow.document.open
        @node.contentWindow.document.write html
        do @node.contentWindow.document.close

        # Refer to the iframe's document.
        @el = window.frames[name]

    error: (message) ->
        do @dispose
        throw message

    dispose: ->
        return if @disposed
        @disposed = yes

        # Destroy DOM (cross-browser).
        if @node
            switch
                # Chrome.
                when _.isFunction @node.remove
                    do @node.remove
                # IE.
                when _.isFunction @node.removeNode
                    @node.removeNode yes
                # This one "should" work.
                when @node.parentNode
                    @node.parentNode.removeChild @node

        # No moar change.
        Object.freeze? @

module.exports = Iframe