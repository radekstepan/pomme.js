Pomme = require 'pomme.js'

# A template requiring the libs.
template = (listeners='') ->
    ({ scope }) ->
        scope ?= 'testScope'
        """
        <script src="/build/app.bundle.js"></script>
        <script>
            var Pomme = require('pomme.js');
            var channel = new Pomme({ 'scope': '#{scope}' });

            #{listeners}
        </script>
        """

suite 'pomme.js', ->

    test 'should have separate channels', (done) ->
        a = new Pomme { 'target': 'body', 'template': do template }
        b = new Pomme { 'target': 'body', 'template': do template }

        assert.equal a.id, 0
        assert.equal b.id, 1

        do a.dispose
        do b.dispose

        do done

    test 'should be able to trigger a function with a callback', (done) ->
        channel = new Pomme
            'target': 'body'
            'template': template """
                channel.on('fn', function(cb) {
                    cb(null, 'ok');
                });
                """

        channel.trigger 'fn', (err, res) ->
            assert.ifError err
            assert.equal res, 'ok'
            do channel.dispose
            do done

    test 'should trigger error event on circular objects', (done) ->
        channel = new Pomme { 'target': 'body', 'template': do template }
        
        obj = {}
        obj.key = obj

        channel.on 'error', (err) ->
            assert.equal err, 'cannot convert circular structure'

        channel.trigger 'fn', obj

        do channel.dispose
        do done

    test 'should be silent when error handler is not provided', (done) ->
        channel = new Pomme { 'target': 'body', 'template': do template }
        
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
            'template': template """
                var obj = {};
                obj.key = obj;

                channel.trigger('fn', obj);
                """

        channel.on 'error', (err) ->
            assert.equal err, 'cannot convert circular structure'
            do channel.dispose
            do done

    test 'should be able to bubble up thrown errors from a child', (done) ->
        channel = new Pomme
            'target': 'body'
            'template': template """
                channel.on('fn', function(cb) {
                    throw 'Some error'
                });
                """

        channel.on 'error', (err) ->
            assert.equal err, 'Some error'
            do channel.dispose
            do done

        channel.trigger 'fn', ->

    test 'should be able to pass multiple params', (done) ->
        channel = new Pomme
            'target': 'body'
            'template': template """
                channel.on('swapper', function(a, b, complex, cb) {
                    cb(null, JSON.stringify(complex), b, a);
                });
                """

        # Eat that.
        complex = [
            {
                'hello':
                    'world': [
                        1, 2, { 1: ( -> ) }
                    ]
            }
        ]

        channel.trigger 'swapper', 'A', 'B', complex, (err, string, b, a) ->
            assert.ifError err
            assert.equal string, '[{"hello":{"world":[1,2,{}]}}]'
            assert.equal a, 'A'
            assert.equal b, 'B'
            do channel.dispose
            do done

    test 'should be able to eval by default', (done) ->
        channel = new Pomme { 'target': 'body', 'template': do template }

        channel.on 'error', (err) ->
            assert.ifError err

        channel.on 'response', (res) ->
            assert.equal res, 'ok'
            do channel.dispose
            do done

        channel.trigger 'eval', "channel.trigger('response', 'ok');"

    test 'no cross channel comms', (done) ->
        a = new Pomme { 'target': 'body', 'template': do template }
        b = new Pomme { 'target': 'body', 'template': do template }

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
        channel = new Pomme { 'target': 'body', 'template': do template }

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
        assert _.isEqual channel.handlers, {}

        do done

    test 'should unbind handlers', (done) ->
        channel = new Pomme { 'target': 'body', 'template': do template }

        channel.on 'something', ->

        assert 'something' of channel.handlers

        channel.unbind 'something'

        assert 'something' not of channel.handlers

        do done
        do channel.dispose

    test 'should bind to functions', (done) ->
        channel = new Pomme { 'target': 'body', 'template': do template }

        channel.on 'error', (err) ->
            assert.equal err, 'callback missing'
            do channel.dispose
            do done

        channel.on 'something', no

    test 'should throw when unbinding nonexistent handlers', (done) ->
        channel = new Pomme { 'target': 'body', 'template': do template }

        channel.on 'error', (err) ->
            assert.equal err, '`weird` is not bound'
            do channel.dispose
            do done

        channel.unbind 'weird'

    test 'should throw on when no target passed to parent', (done) ->
        try
            channel = new Pomme()
        catch err
            assert.equal do err.toString, 'Error: child and parent windows cannot be one and the same'
            do done

    test 'should throw when window target is nonexistent', (done) ->
        try
            channel = new Pomme { 'target': 666 }
        catch err
            assert.equal do err.toString, 'target selector not found'
            do done

    test 'should throw when template is not a function', (done) ->
        try
            channel = new Pomme { 'target': 'body', 'template': 666 }
        catch err
            assert.equal do err.toString, 'template is not a function'
            do done

    test 'should throw when template does not return a string', (done) ->
        try
            channel = new Pomme { 'target': 'body', 'template': -> 666 }
        catch err
            assert.equal do err.toString, 'template did not return a string'
            do done

    test 'should accept only strings as a scope', (done) ->
        try
            channel = new Pomme { 'target': 'body', 'scope': -> }
        catch e
            do done

    test 'should be able to use an iframe as a target', (done) ->
        a = new Pomme { 'target': 'body', 'scope': 'a', 'template': do template }
        b = new Pomme { 'target': a.window, 'scope': 'b', 'template': do template }

        a.on 'response', (res) ->
            assert false

        b.on 'response', (res) ->
            assert.equal res, 'ok'
            do a.dispose
            do b.dispose
            do done

        a.trigger 'eval', """
            var test = new Pomme({'scope': 'b'});
            test.on('query', function() {
                test.trigger('response', 'ok');
            });
            """

        a.trigger('query')
        b.trigger('query')

    test 'should throw when registering the same window and scope', (done) ->
        a = new Pomme { 'target': 'body', 'scope': 'a', 'template': do template }

        try
            b = new Pomme 'target': a.window, 'scope': 'a'
        catch err
            assert.equal do err.toString, 'Error: a channel is already bound to the same window under `a`'
            do a.dispose
            do done

    test 'should allow chaining of trigger', (done) ->
        channel = new Pomme { 'target': 'body', 'template': do template }

        i = 0
        channel.on 'response', ->
            i++
            if i is 2
                do channel.dispose
                do done

        channel
        .trigger('eval', "channel.trigger('response')")
        .trigger('eval', "channel.trigger('response')")

    test 'should allow chaining of on', (done) ->
        channel = new Pomme { 'target': 'body', 'template': do template }

        i = 0
        handle = ->
            i++
            if i is 2
                do channel.dispose
                do done

        channel
        .on('a', handle)
        .on('b', handle)

        channel.trigger 'eval', """
            channel.trigger('a');
            channel.trigger('b');
            """

do mocha.run