Sam = require 'samskipti'

suite 'Samskipti', ->
    chanAppsA = new Sam
        'target': 'body'
        'scope': 'appsA'
        'debug': yes

    test 'should get response to a message from parent', (done) ->
        chanAppsA.trigger
            'method': 'load'
            'params':
                'text': 'ABC'
            success: (v) ->
                assert.equal 'CBA', v
                do done
            error: (err, message) ->
                assert.ifError err

do mocha.run