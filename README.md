#samskipti

JS comms between parent and child frame.

```bash
$ npm install
$ make [build|watch|serve]
```

##Use it

You can see an example in `/test/tests.coffee`.

###Config

####scope (parent & child)

Scope is an identifier used by a router to work out how to route messages. It is not strictly required as when you only have 1 parent-child pair, there isn't much guesswork involved...

####target (parent)

This will be the place where your iframe will be rendered.

####template (parent)

The value here is a function being passed abovementioned `scope`. This function should return an HTML string (not CoffeeScript) that will be injected into the child iframe. It needs to setup the comms from the other end.

```javascript
var Sam = require('samskipti'); // wherever this is served from
var channel = new Sam();
// ...
```

###Methods

As a parent, you invoke functions on the child like so:

```coffeescript
# Assuming this channel is scoped with the parent.
channel.trigger 'reverse', 'ABC', (err, result) ->
    throw err if err
    console.log result
```

As a child you listen on a channel for invokations:

```coffeescript
channel.on 'reverse', (text, cb) ->
    try
        result = text.split('').reverse().join('')
        cb null, result
    catch err
        cb err
```

####Errors

On top of that, you can be listening for error that happen on the parent and/or child. So in your parent you would do:

```coffeescript
channel.on 'error', (err) ->
    throw err

channel.trigger 'die'
```

And your child could do this:

```coffeescript
channel.on 'die', ->
    throw 'I am dead'
```

If you do not specify your own error handler, nothing is thrown/logged.

##Test it

You can see Mocha tests by serving the `/test` directory and opening it in the browser.