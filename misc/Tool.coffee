# Make sure we are clean.
$(target).html('')

# Create the iframe.
iframe = document.createElement 'iframe'
iframe.name = 'frame'
iframe.src = '/iframe.html'
$(target)[0].appendChild(iframe)

# Refer to the iframe's document.
child = window.frames['frame']

# Build a channel with the child.
channel = new Samskipti 'A',
    'window': child
    'origin': '*'
    'scope': 'steps'
, cb