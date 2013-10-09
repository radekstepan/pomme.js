Sam = require 'samskipti'

suite 'Samskitpit', ->
    test 'should get response to a message from parent', (done) ->
        chanAppsA = new Sam
            'window': document.getElementById('child').contentWindow
            'scope': 'appsA'
            'debug': yes

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