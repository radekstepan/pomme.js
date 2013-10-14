Sam = require 'samskipti'

suite 'Samskipti', ->

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

do mocha.run