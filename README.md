#pomme.js

JavaScript component for communication between parent and child browser frames using [postMessage](http://devdocs.io/dom/window.postmessage).

![image](https://raw.github.com/radekstepan/pomme.js/master/example.png)

```bash
$ npm install
$ make [build|install|watch|serve]
```

##Use it

Grab one of the `/build` files:

1. `app.js`: contains just the app
1. `app.bundle.js`: contains the app and its dependency, [Underscore](http://underscorejs.org/). In addition, JSON is used to un-/pickle objects. Make sure it is present.

If you would like to see how are these files being built check out `Gruntfile.coffee`.

The app works only in the browser. There, depending on the environment, it will be available as a:

###RequireJS/AMD module

Please note that you need to make sure the dependencies are loaded first.

```javascript
requirejs([ 'pomme.js' ], function(Pomme) {
  // ...
});
```

###CommonJS module

The internal loader will be made available globally as well if `window.require` is free.

```javascript
var Pomme = require('pomme.js');
```

###Property of `window` object

```javascript
var Pomme = window['pomme.js'];
```

Do not forget the `.` in the name...

You can see examples of usage in `/test/tests.coffee`.

###Config

<dl>
  <dt>scope (parent &amp; child)</dt>
  <dd>Scope is an identifier used by a router to work out how to route messages. It is not strictly required as when you only have 1 parent-child pair, there isn't much guesswork involved...</dd>

  <dt>target (parent)</dt>
  <dd>This will be the place where your iframe will be rendered. Pass a string selector that works with <code>document.querySelector</code> or an instance of <code>window</code>.</dd>

  <dt>template (parent)</dt>
  <dd>The value here is a function being passed abovementioned <code>scope</code>. This function should return an <strong>html string</strong> that will be injected into the child iframe. It needs to setup the comms from the other end.</dd>
</dl>

```javascript
// wherever this is served from
var Pomme = require('pomme.js');
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

By default, an `eval` listener is provided in the child, so you can execute code in the context of the child. Remember that the context of the execution will be the `window`. A better solution is to write a template though. In either case, we inject a string of code to the iframe to be executed.

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

You can see [Mocha](http://mochajs.org/) tests by serving the `/test` directory and opening it in the browser. If you have Python installed then run the following:

```bash
$ make serve
# visit http://127.0.0.1:1893/test/
```

[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/radekstepan/pomme.js/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

