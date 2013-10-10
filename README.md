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
channel.trigger
    'method': 'reverse'
    'params': { 'text': 'ABC' }
    success: (response) ->
    error: (err, message) ->
```

As a child you listen on a channel for invokations:

```coffeescript
channel.on 'reverse', ({ text }) ->
    text.split('').reverse().join('')
```

##Test it

You can see Mocha tests by serving the `/test` directory and opening it in the browser.