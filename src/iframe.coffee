constants = require './constants'

class iFrame

    constructor: ({ id, target, scope, template }) ->
        @name = constants.iframe + id or + new Date

        # Create the iframe.
        iframe = document.createElement 'iframe'
        iframe.name = @name
        document.querySelector(target).appendChild iframe

        # Use a custom template or go spec one?
        template ?= require './template'
        # Pass it scope.
        html = template { scope }

        # Write custom content.
        do iframe.contentWindow.document.open
        iframe.contentWindow.document.write html
        do iframe.contentWindow.document.close

        # Hide it by default.
        iframe.style.border = 0
        iframe.style.height = 0
        iframe.style.width = 0

        # Refer to the iframe's document.
        @el = window.frames[@name]

module.exports = iFrame