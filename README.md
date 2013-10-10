#samskipti

JS comms between parent and child frame.

```bash
$ npm install
$ make [build|watch|serve]
```

##Use it

You can see an example in `/test/tests.coffee`. The following are the config options passed to the app.

###target

This will be the place where your iframe will be rendered.

###scope

Scope is an identifier used by a router to work out how to route messages. It is not strictly required as when you only have 1 parent-child pair, there isn't much guesswork involved...

###template

The value here is a function being passed abovementioned `scope`. This function should return an HTML string that will be injected into the child iframe. At the minimum it this needs to require the app and listen to messages:

```coffeescript
// ...
channel.on('method', function(args) {
    return args.text.toLowerCase();
});
```

##Test it

You can see Mocha tests by serving the `/test` directory and opening it in the browser.