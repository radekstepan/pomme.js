(function() {
    var Pomme, template;

    Pomme = require('pomme.js');

    template = function(listeners) {
        if (listeners == null) {
            listeners = '';
        }
        return function(_arg) {
            var scope;
            scope = _arg.scope;
            if (scope == null) {
                scope = 'testScope';
            }
            return "<script src=\"/build/app.bundle.js\"></script>\n<script>\n        var Pomme = require('pomme.js');\n        var channel = new Pomme({ 'scope': '" + scope + "' });\n\n        " + listeners + "\n</script>";
        };
    };

    suite('pomme.js', function() {
        
        test('should have separate channels', function(done) {
            var a, b;
            a = new Pomme({
                'target': 'body',
                'template': template()
            });
            b = new Pomme({
                'target': 'body',
                'template': template()
            });
            assert.equal(a.id, 0);
            assert.equal(b.id, 1);
            a.dispose();
            b.dispose();
            return done();
        });
        
        test('should be able to trigger a function with a callback', function(done) {
            var channel;
            channel = new Pomme({
                'target': 'body',
                'template': template("channel.on('fn', function(cb) {\n        cb(null, 'ok');\n});")
            });
            return channel.trigger('fn', function(err, res) {
                assert.ifError(err);
                assert.equal(res, 'ok');
                channel.dispose();
                return done();
            });
        });
        
        test('should trigger error event on circular objects', function(done) {
            var channel, obj;
            channel = new Pomme({
                'target': 'body',
                'template': template()
            });
            obj = {};
            obj.key = obj;
            channel.on('error', function(err) {
                return assert.equal(err, 'cannot convert circular structure');
            });
            channel.trigger('fn', obj);
            channel.dispose();
            return done();
        });
        
        test('should be silent when error handler is not provided', function(done) {
            var channel, err, obj;
            channel = new Pomme({
                'target': 'body',
                'template': template()
            });
            obj = {};
            obj.key = obj;
            try {
                channel.trigger('fn', obj);
            } catch (_error) {
                err = _error;
                assert.ifError(err);
            }
            channel.dispose();
            return done();
        });
        
        test('should be able to bubble errors up from a child', function(done) {
            var channel;
            channel = new Pomme({
                'target': 'body',
                'template': template("var obj = {};\nobj.key = obj;\n\nchannel.trigger('fn', obj);")
            });
            return channel.on('error', function(err) {
                assert.equal(err, 'cannot convert circular structure');
                channel.dispose();
                return done();
            });
        });
        
        test('should be able to bubble up thrown errors from a child', function(done) {
            var channel;
            channel = new Pomme({
                'target': 'body',
                'template': template("channel.on('fn', function(cb) {\n        throw 'Some error'\n});")
            });
            channel.on('error', function(err) {
                assert.equal(err, 'Some error');
                channel.dispose();
                return done();
            });
            return channel.trigger('fn', function() {});
        });
        
        test('should be able to pass multiple params', function(done) {
            var channel, complex;
            channel = new Pomme({
                'target': 'body',
                'template': template("channel.on('swapper', function(a, b, complex, cb) {\n        cb(null, JSON.stringify(complex), b, a);\n});")
            });
            complex = [
                {
                    'hello': {
                        'world': [
                            1, 2, {
                                1: (function() {})
                            }
                        ]
                    }
                }
            ];
            return channel.trigger('swapper', 'A', 'B', complex, function(err, string, b, a) {
                assert.ifError(err);
                assert.equal(string, '[{"hello":{"world":[1,2,{}]}}]');
                assert.equal(a, 'A');
                assert.equal(b, 'B');
                channel.dispose();
                return done();
            });
        });
        
        test('should be able to eval by default', function(done) {
            var channel;
            channel = new Pomme({
                'target': 'body',
                'template': template()
            });
            channel.on('error', function(err) {
                return assert.ifError(err);
            });
            channel.on('response', function(res) {
                assert.equal(res, 'ok');
                channel.dispose();
                return done();
            });
            return channel.trigger('eval', "channel.trigger('response', 'ok');");
        });
        
        test('no cross channel comms', function(done) {
            var a, b, fin, i;
            a = new Pomme({
                'target': 'body',
                'template': template()
            });
            b = new Pomme({
                'target': 'body',
                'template': template()
            });
            i = 0;
            fin = function() {
                i++;
                if (i === 2) {
                    a.dispose();
                    b.dispose();
                    return done();
                }
            };
            a.on('response', function(res) {
                assert.equal(res, 'A');
                return fin();
            });
            b.on('response', function(res) {
                assert.equal(res, 'B');
                return fin();
            });
            b.trigger('eval', "channel.trigger('response', 'B');");
            return a.trigger('eval', "channel.trigger('response', 'A');");
        });
        
        test('should dispose itself', function(done) {
            var channel, length;
            channel = new Pomme({
                'target': 'body',
                'template': template()
            });
            length = window.frames.length;
            channel.on('random', function() {});
            channel.dispose();
            channel.trigger('noregister', function() {});
            assert.equal(window.frames.length, length - 1);
            assert(_.isEqual(channel.handlers, {}));
            return done();
        });
        
        test('should unbind handlers', function(done) {
            var channel;
            channel = new Pomme({
                'target': 'body',
                'template': template()
            });
            channel.on('something', function() {});
            assert('something' in channel.handlers);
            channel.unbind('something');
            assert(!('something' in channel.handlers));
            done();
            return channel.dispose();
        });
        
        test('should bind to functions', function(done) {
            var channel;
            channel = new Pomme({
                'target': 'body',
                'template': template()
            });
            channel.on('error', function(err) {
                assert.equal(err, 'callback missing');
                channel.dispose();
                return done();
            });
            return channel.on('something', false);
        });
        
        test('should throw when unbinding nonexistent handlers', function(done) {
            var channel;
            channel = new Pomme({
                'target': 'body',
                'template': template()
            });
            channel.on('error', function(err) {
                assert.equal(err, '`weird` is not bound');
                channel.dispose();
                return done();
            });
            return channel.unbind('weird');
        });
        
        test('should throw on when no target passed to parent', function(done) {
            var channel, err;
            try {
                return channel = new Pomme();
            } catch (_error) {
                err = _error;
                assert.equal(err.toString(), 'Error: child and parent windows cannot be one and the same');
                return done();
            }
        });
        
        test('should throw when window target is nonexistent', function(done) {
            var channel, err;
            try {
                return channel = new Pomme({
                    'target': 666
                });
            } catch (_error) {
                err = _error;
                assert.equal(err.toString(), 'target selector not found');
                return done();
            }
        });
        
        test('should throw when template is not a function', function(done) {
            var channel, err;
            try {
                return channel = new Pomme({
                    'target': 'body',
                    'template': 666
                });
            } catch (_error) {
                err = _error;
                assert.equal(err.toString(), 'template is not a function');
                return done();
            }
        });
        
        test('should throw when template does not return a string', function(done) {
            var channel, err;
            try {
                return channel = new Pomme({
                    'target': 'body',
                    'template': function() {
                        return 666;
                    }
                });
            } catch (_error) {
                err = _error;
                assert.equal(err.toString(), 'template did not return a string');
                return done();
            }
        });
        
        test('should accept only strings as a scope', function(done) {
            var channel, e;
            try {
                return channel = new Pomme({
                    'target': 'body',
                    'scope': function() {}
                });
            } catch (_error) {
                e = _error;
                return done();
            }
        });
        
        test('should be able to use an iframe as a target', function(done) {
            var a, b;
            a = new Pomme({
                'target': 'body',
                'scope': 'a',
                'template': template()
            });
            b = new Pomme({
                'target': a.window,
                'scope': 'b',
                'template': template()
            });
            a.on('response', function(res) {
                return assert(false);
            });
            b.on('response', function(res) {
                assert.equal(res, 'ok');
                a.dispose();
                b.dispose();
                return done();
            });
            a.trigger('eval', "var test = new Pomme({'scope': 'b'});\ntest.on('query', function() {\n        test.trigger('response', 'ok');\n});");
            a.trigger('query');
            return b.trigger('query');
        });
        
        test('should throw when registering the same window and scope', function(done) {
            var a, b, err;
            a = new Pomme({
                'target': 'body',
                'scope': 'a',
                'template': template()
            });
            try {
                return b = new Pomme({
                    'target': a.window,
                    'scope': 'a'
                });
            } catch (_error) {
                err = _error;
                assert.equal(err.toString(), 'Error: a channel is already bound to the same window under `a`');
                a.dispose();
                return done();
            }
        });
        
        test('should allow chaining of trigger', function(done) {
            var channel, i;
            channel = new Pomme({
                'target': 'body',
                'template': template()
            });
            i = 0;
            channel.on('response', function() {
                i++;
                if (i === 2) {
                    channel.dispose();
                    return done();
                }
            });
            return channel.trigger('eval', "channel.trigger('response')").trigger('eval', "channel.trigger('response')");
        });
        return test('should allow chaining of on', function(done) {
            var channel, handle, i;
            channel = new Pomme({
                'target': 'body',
                'template': template()
            });
            i = 0;
            handle = function() {
                i++;
                if (i === 2) {
                    channel.dispose();
                    return done();
                }
            };
            channel.on('a', handle).on('b', handle);
            return channel.trigger('eval', "channel.trigger('a');\nchannel.trigger('b');");
        });
    });

    mocha.run();

}).call(this);