tml = require './template'

class iFrame

    constructor: (opts) ->
        @name = '__samskipti::' + opts.id

        # Create the iframe.
        iframe = document.createElement 'iframe'
        iframe.name = @name
        document.querySelector(opts.target).appendChild iframe

        # Write custom content.
        iframe.contentWindow.document.open()
        iframe.contentWindow.document.write(do tml)
        iframe.contentWindow.document.close()

        # Hide it.
        iframe.style.border = 0

        # Refer to the iframe's document.
        @el = window.frames[@name]

module.exports = iFrame