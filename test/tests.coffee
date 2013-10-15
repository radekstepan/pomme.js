_ = require 'lodash'

Pomme = require 'pomme'

suite 'pomme.js', ->

    test 'should have separate channels', (done) ->
        a = new Pomme 'target': 'body'
        b = new Pomme 'target': 'body'

        assert.equal a.id, 0
        assert.equal b.id, 1

        do a.dispose
        do b.dispose
        do done

    test 'should be able to trigger a function with a callback', (done) ->
        channel = new Pomme
            'target': 'body'
            'template': ({ scope }) -> """
                <script src="assets/build.js"></script>
                <script>
                (function() {
                    var Pomme = require('pomme');
                    
                    var channel = new Pomme();
                    
                    channel.on('fn', function(cb) {
                        cb(null, 'ok');
                    });
                })();
                </script>
            """

        channel.trigger 'fn', (err, res) ->
            assert.ifError err
            assert.equal res, 'ok'
            do channel.dispose
            do done

    test 'should trigger error event on circular objects', (done) ->
        channel = new Pomme 'target': 'body'
        
        obj = {}
        obj.key = obj

        channel.on 'error', (err) ->
            assert.equal err, 'Converting circular structure to JSON'

        channel.trigger 'fn', obj

        do channel.dispose
        do done

    test 'should be silent when error handler is not provided', (done) ->
        channel = new Pomme 'target': 'body'
        
        obj = {}
        obj.key = obj

        try
            channel.trigger 'fn', obj
        catch err
            assert.ifError err

        do channel.dispose
        do done

    test 'should be able to bubble errors up from a child', (done) ->
        channel = new Pomme
            'target': 'body'
            'template': ({ scope }) -> """
                <script src="assets/build.js"></script>
                <script>
                (function() {
                    var Pomme = require('pomme');
                    
                    var channel = new Pomme();
                    
                    var obj = {};
                    obj.key = obj;

                    channel.trigger('fn', obj);
                })();
                </script>
            """

        channel.on 'error', (err) ->
            assert.equal err, 'Converting circular structure to JSON'
            do channel.dispose
            do done

    test 'should be able to bubble up thrown errors from a child', (done) ->
        channel = new Pomme
            'target': 'body'
            'template': ({ scope }) -> """
                <script src="assets/build.js"></script>
                <script>
                (function() {
                    var Pomme = require('pomme');
                    
                    var channel = new Pomme();

                    channel.on('fn', function(cb) {
                        throw 'Some error'
                    });
                })();
                </script>
            """

        channel.on 'error', (err) ->
            assert.equal err, 'Some error'
            do channel.dispose
            do done

        channel.trigger 'fn', ->

    test 'should be able to pass multiple params', (done) ->
        channel = new Pomme
            'target': 'body'
            'template': ({ scope }) -> """
                <script src="assets/build.js"></script>
                <script>
                (function() {
                    var Pomme = require('pomme');
                    
                    var channel = new Pomme();
                    
                    channel.on('swapper', function(a, b, cb) {
                        cb(null, b, a);
                    });
                })();
                </script>
            """

        channel.trigger 'swapper', 'A', 'B', (err, b, a) ->
            assert.ifError err
            assert.equal a, 'A'
            assert.equal b, 'B'
            do channel.dispose
            do done

    test 'should be able to eval by default', (done) ->
        channel = new Pomme 'target': 'body'

        channel.on 'error', (err) ->
            assert.ifError err

        channel.on 'response', (res) ->
            assert.equal res, 'ok'
            do channel.dispose
            do done

        channel.trigger 'eval', "channel.trigger('response', 'ok');"

    test 'no cross channel comms', (done) ->
        a = new Pomme 'target': 'body'
        b = new Pomme 'target': 'body'

        i = 0
        fin = ->
            i++
            if i is 2
                do a.dispose
                do b.dispose
                do done

        a.on 'response', (res) ->
            assert.equal res, 'A'
            do fin

        b.on 'response', (res) ->
            assert.equal res, 'B'
            do fin

        b.trigger 'eval', "channel.trigger('response', 'B');"
        a.trigger 'eval', "channel.trigger('response', 'A');"

    test 'should dispose itself', (done) ->
        channel = new Pomme 'target': 'body'

        # All the iframes.
        length = window.frames.length

        # Register a handler.
        channel.on 'random', ->

        # Dispose.
        do channel.dispose

        # Trigger that will try to write a callback handler.
        channel.trigger 'noregister', ->

        # Make sure we have one less frame.
        assert.equal window.frames.length, length - 1

        # Check the handlers present.
        assert.equal _.keys(channel.handlers).length, 0

        do done
        do channel.dispose

    test 'should unbind handlers', (done) ->
        channel = new Pomme 'target': 'body'

        channel.on 'something', ->

        assert 'something' of channel.handlers

        channel.unbind 'something'

        assert 'something' not of channel.handlers

        do done
        do channel.dispose

    test 'should bind to functions', (done) ->
        channel = new Pomme 'target': 'body'

        channel.on 'error', (err) ->
            assert.equal err, 'callback missing'
            do channel.dispose
            do done

        channel.on 'something', no

    test 'should throw when unbinding nonexistent handlers', (done) ->
        channel = new Pomme 'target': 'body'

        channel.on 'error', (err) ->
            assert.equal err, '`weird` is not bound'
            do channel.dispose
            do done

        channel.unbind 'weird'

    test 'should throw on when no target passed to parent', (done) ->
        try
            channel = new Pomme()
        catch err
            assert.equal do err.toString, 'child and parent windows cannot be one and the same'
            do done

    test 'should throw when window target is nonexistent', (done) ->
        try
            channel = new Pomme 'target': 666
        catch err
            assert.equal do err.toString, 'target selector cannot be found'
            do done

    test 'should throw when template is not a function', (done) ->
        try
            channel = new Pomme 'target': 'body', 'template': 666
        catch err
            assert.equal do err.toString, 'template is not a function'
            do done

    test 'should throw when template does not return a string', (done) ->
        try
            channel = new Pomme 'target': 'body', 'template': -> 666
        catch err
            assert.equal do err.toString, 'template did not return a string'
            do done

    test 'should accept any possible item as a scope', (done) ->
        channel = new Pomme 'target': 'body', 'scope': ->

        channel.on 'error', (err) ->
            assert.equal err, 'ok'
            do channel.dispose
            do done

        channel.trigger 'eval', "throw 'ok'"

do mocha.run