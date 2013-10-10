Sam = require 'samskipti'

suite 'Samskipti', ->

    test 'should get response to a message from parent', (done) ->
        channel = new Sam
            'target': 'body'

        channel.trigger
            'method': 'reverse'
            'params':
                'text': 'ABC'
            success: (v) ->
                assert.equal 'CBA', v
                do done
            error: (err, message) ->
                assert.ifError err

    test 'should be able to inject a custom template', (done) ->
        channel = new Sam
            'target': 'body'
            'template': ({ scope }) -> """
                <script src="assets/build.js"></script>
                <script>
                (function() {
                    var Sam = require('samskipti');
                    
                    var channel = new Sam();
                    
                    channel.on('lowercase', function(obj) {
                        return obj.text.toLowerCase();
                    });
                })();
                </script>
            """

        channel.trigger
            'method': 'lowercase'
            'params':
                'text': 'DEF'
            success: (v) ->
                assert.equal 'def', v
                do done
            error: (err, message) ->
                assert.ifError err

do mocha.run