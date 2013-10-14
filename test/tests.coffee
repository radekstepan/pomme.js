Sam = require 'samskipti'

suite 'Samskipti', ->

    test 'should have separate channels', (done) ->
        a = new Sam 'target': 'body'
        b = new Sam 'target': 'body'

        assert.equal a.id, 0
        assert.equal b.id, 1

        do done

    test 'should be able to trigger a function with a callback', (done) ->
        channel = new Sam
            'target': 'body'
            'template': ({ scope }) -> """
                <script src="assets/build.js"></script>
                <script>
                (function() {
                    var Sam = require('samskipti');
                    
                    var channel = new Sam();
                    
                    channel.on('fn', function(cb) {
                        cb(null, 'ok');
                    });
                })();
                </script>
            """

        channel.trigger 'fn', (err, res) ->
            assert.ifError err
            assert.equal res, 'ok'
            do done

    test 'should trigger error event on circular objects', (done) ->
        channel = new Sam 'target': 'body'
        
        obj = {}
        obj.key = obj

        channel.on 'error', (err) ->
            assert.equal err, 'Converting circular structure to JSON'

        channel.trigger 'fn', obj

        do done

    test 'should be silent when error handler is not provided', (done) ->
        channel = new Sam 'target': 'body'
        
        obj = {}
        obj.key = obj

        try
            channel.trigger 'fn', obj
        catch err
            assert.ifError err

        do done

    test 'should be able to bubble errors up from a child', (done) ->
        channel = new Sam
            'target': 'body'
            'template': ({ scope }) -> """
                <script src="assets/build.js"></script>
                <script>
                (function() {
                    var Sam = require('samskipti');
                    
                    var channel = new Sam();
                    
                    var obj = {};
                    obj.key = obj;

                    channel.trigger('fn', obj);
                })();
                </script>
            """

        channel.on 'error', (err) ->
            assert.equal err, 'Converting circular structure to JSON'
            do done

    test 'should be able to bubble up thrown errors from a child', (done) ->
        channel = new Sam
            'target': 'body'
            'template': ({ scope }) -> """
                <script src="assets/build.js"></script>
                <script>
                (function() {
                    var Sam = require('samskipti');
                    
                    var channel = new Sam();

                    channel.on('fn', function(cb) {
                        throw 'Some error'
                    });
                })();
                </script>
            """

        channel.on 'error', (err) ->
            assert.equal err, 'Some error'
            do done

        channel.trigger 'fn', ->

do mocha.run