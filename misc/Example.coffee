# Pass the following to the App from the client.
opts =
    'mine': config.root # which mine to connect to
    'token': config.token # token so we can access private lists
    # Status messages and when user submits a list.
    'cb': (err, working, list) ->
        # Has error happened?
        throw err if err
        # Have input?
        if list
            # Save the input proper.
            self.model.set 'data', 'list': list
            # Update the history, we are set.
            Mediator.publish 'history:add', self.model

# Build me an iframe with a channel.
channel = @makeIframe '.iframe.app.container', (err) ->
    throw err if err

# Make me an app.
channel.invoke.apps 'choose-list', opts