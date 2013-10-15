#pomme.js

JavaScript component for communication between parent and child browser frames using [postMessage](http://devdocs.io/dom/window.postmessage).

```bash
$ npm install
$ make [build|watch|serve]
```

##Use it

You can see an example in `/test/tests.coffee`.

###Config

<dl>
  <dt>scope (parent & child)</dt>
  <dd>Scope is an identifier used by a router to work out how to route messages. It is not strictly required as when you only have 1 parent-child pair, there isn't much guesswork involved...</dd>

  <dt>target (parent)</dt>
  <dd>This will be the place where your iframe will be rendered.</dd>

  <dt>template (parent)</dt>
  <dd>The value here is a function being passed abovementioned `scope`. This function should return an **HTML string** that will be injected into the child iframe. It needs to setup the comms from the other end.</dd>
</dl>

```javascript
// wherever this is served from
var Pomme = require('pomme');
// Probably needs some params, see above.
var channel = new Pomme();
// ...
```

###Methods

As a parent, you invoke functions on the child like so:

```javascript
// Assuming this channel is scoped with the parent.
channel.trigger('glitchy', 'ABC', function(err, result) {
    if (err) throw err;
    console.log(result);
});
```

As a child you listen on a channel for invokations:

```javascript
channel.on('glitchy', function(text, cb) {
    if (Math.floor(Math.random() * 2) == 1) {
        cb(null, text.split('').reverse().join(''));
    } else {
        cb('mañana');
    }
});
```

By default, an `eval` listener is provided in the child, so you can execute code in the context of the child. A better solution is to write a template though. In either case, we inject a string of code to the iframe to be executed.

####Errors

On top of that, you can be listening for error that happen on the parent and/or child. So in your parent you would do:

```javascript
// Listen for errors.
channel.on('error', function(err) {
    throw err;
});

// Trigger on child.
channel.trigger('die');
```

And your child could do this:

```javascript
channel.on('die', function() {
    throw 'I am dead';
});
```

If you do not specify your own error handler, nothing is thrown/logged.

##Test it

You can see [Mocha](http://visionmedia.github.io/mocha/) tests by serving the `/test` directory and opening it in the browser.