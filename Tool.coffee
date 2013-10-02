Samskipti = require 'iframe/Samskipti'

# Make an iframe and return a channel to it.
makeIframe = (target, cb) ->
    # Make sure we are clean.
    $(target).html('')

    # Create the iframe.
    iframe = document.createElement 'iframe'
    iframe.name = 'frame'
    iframe.src = '/iframe.html'
    $(target)[0].appendChild(iframe)

    # Refer to the iframe's document.
    child = window.frames['frame']

    # Start auto-resizing (interval is cleared in `dispose`).
    @intervals ?= []
    @intervals.push setInterval ->
        if body = child.document.body
            height = body.scrollHeight
            iframe.style.height = "#{height}px"
    , 1e2

    # Build a channel with the child.
    channel = new Samskipti 'A',
        'window': child
        'origin': '*'
        'scope': 'steps'
    , cb