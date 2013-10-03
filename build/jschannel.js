// Generated by CoffeeScript 1.6.3
(function() {
  var root,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  root = this;

  root.Channel = (function() {
    var s_addBoundChan, s_boundChans, s_curTranId, s_isArray, s_onMessage, s_removeBoundChan, s_transIds;
    s_curTranId = Math.floor(Math.random() * 1000001);
    s_boundChans = {};
    s_addBoundChan = function(win, origin, scope, handler) {
      var exists, hasWin, k;
      hasWin = function(arr) {
        var x, _i, _len;
        for (_i = 0, _len = arr.length; _i < _len; _i++) {
          x = arr[_i];
          if (x.win === win) {
            return true;
          }
        }
        return false;
      };
      exists = false;
      if (origin === "*") {
        for (k in s_boundChans) {
          if (!s_boundChans.hasOwnProperty(k)) {
            continue;
          }
          if (k === "*") {
            continue;
          }
          if (typeof s_boundChans[k][scope] === "object") {
            exists = hasWin(s_boundChans[k][scope]);
            if (exists) {
              break;
            }
          }
        }
      } else {
        if (s_boundChans["*"] && s_boundChans["*"][scope]) {
          exists = hasWin(s_boundChans["*"][scope]);
        }
        if (!exists && s_boundChans[origin] && s_boundChans[origin][scope]) {
          exists = hasWin(s_boundChans[origin][scope]);
        }
      }
      if (exists) {
        throw "A channel is already bound to the same root which overlaps with origin '" + origin + "' and has scope '" + scope + "'";
      }
      if (typeof s_boundChans[origin] !== "object") {
        s_boundChans[origin] = {};
      }
      if (typeof s_boundChans[origin][scope] !== "object") {
        s_boundChans[origin][scope] = [];
      }
      return s_boundChans[origin][scope].push({
        win: win,
        handler: handler
      });
    };
    s_removeBoundChan = function(win, origin, scope) {
      var x;
      s_boundChans[origin][scope] = (function() {
        var _i, _len, _ref, _results;
        _ref = s_boundChans[origin][scope];
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          x = _ref[_i];
          if (x.win === win) {
            _results.push(x);
          }
        }
        return _results;
      })();
      if (!s_boundChans[origin][scope].length) {
        return delete s_boundChans[origin][scope];
      }
    };
    s_isArray = function(obj) {
      if (!Array.isArray) {
        return obj.constructor.toString().indexOf("Array") !== -1;
      }
    };
    s_transIds = {};
    s_onMessage = function(e) {
      var ar, delivered, i, j, m, meth, o, s, w, _i, _j, _ref, _ref1, _results;
      try {
        m = JSON.parse(e.data);
        if (typeof m !== "object" || m === null) {
          throw "malformed";
        }
      } catch (_error) {
        e = _error;
        return;
      }
      w = e.source;
      o = e.origin;
      s = void 0;
      i = void 0;
      meth = void 0;
      if (typeof m.method === "string") {
        ar = m.method.split("::");
        if (ar.length === 2) {
          s = ar[0], meth = ar[1];
        } else {
          meth = m.method;
        }
      }
      if (m.id) {
        i = m.id;
      }
      if (typeof meth === "string") {
        delivered = false;
        if (s_boundChans[o] && s_boundChans[o][s]) {
          for (j = _i = 0, _ref = s_boundChans[o][s]; 0 <= _ref ? _i < _ref : _i > _ref; j = 0 <= _ref ? ++_i : --_i) {
            if (!(s_boundChans[o][s][j].win === w)) {
              continue;
            }
            s_boundChans[o][s][j].handler(o, meth, m);
            delivered = true;
            break;
          }
        }
        if (!delivered && s_boundChans["*"] && s_boundChans["*"][s]) {
          _results = [];
          for (j = _j = 0, _ref1 = s_boundChans["*"][s].length; 0 <= _ref1 ? _j < _ref1 : _j > _ref1; j = 0 <= _ref1 ? ++_j : --_j) {
            if (!(s_boundChans['*'][s][j].win === w)) {
              continue;
            }
            s_boundChans["*"][s][j].handler(o, meth, m);
            break;
          }
          return _results;
        }
      } else if (i) {
        if (s_transIds[i]) {
          return s_transIds[i](o, meth, m);
        }
      }
    };
    switch (false) {
      case !('addEventListener' in root):
        root.addEventListener('message', s_onMessage, false);
        break;
      case !('attachEvent' in root):
        root.attachEvent('onmessage', s_onMessage);
    }
    return {
      'build': function(cfg) {
        var chanId, createTransaction, debug, inTbl, msg, oMatch, obj, onMessage, onReady, outTbl, pendingQueue, postMessage, ready, regTbl, scopeMethod, setTransactionTimeout, validOrigin;
        debug = function(m) {
          var _ref;
          if (cfg.debugOutput && (((_ref = root.console) != null ? _ref.log : void 0) != null)) {
            try {
              if (typeof m !== "string") {
                m = JSON.stringify(m);
              }
            } catch (_error) {}
            return console.log("[" + chanId + "] " + m);
          }
        };
        if (root === cfg.window) {
          throw "target root is same as present root -- not allowed";
        }
        validOrigin = false;
        if (typeof cfg.origin === "string") {
          oMatch = void 0;
          if (cfg.origin === "*") {
            validOrigin = true;
          } else if (null !== (oMatch = cfg.origin.match(/^https?:\/\/(?:[-a-zA-Z0-9_\.])+(?::\d+)?/))) {
            cfg.origin = oMatch[0].toLowerCase();
            validOrigin = true;
          }
        }
        if (!validOrigin) {
          throw "Channel.build() called with an invalid origin";
        }
        if (cfg.scope) {
          if (typeof cfg.scope !== "string") {
            throw "scope, when specified, must be a string";
          }
          if (cfg.scope.split("::").length > 1) {
            throw "scope may not contain double colons: '::'";
          }
        }
        chanId = (function() {
          var alpha, i, text, _i;
          text = "";
          alpha = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
          for (i = _i = 0; _i < 5; i = ++_i) {
            text += alpha.charAt(Math.floor(Math.random() * alpha.length));
          }
          return text;
        })();
        regTbl = {};
        outTbl = {};
        inTbl = {};
        ready = false;
        pendingQueue = [];
        createTransaction = function(id, origin, callbacks) {
          var completed, shouldDelayReturn;
          shouldDelayReturn = false;
          completed = false;
          return {
            'origin': origin,
            'invoke': function(callback, params) {
              var cb, valid, _i, _len;
              if (!inTbl[id]) {
                throw "attempting to invoke a callback of a nonexistent transaction: " + id;
              }
              valid = false;
              for (_i = 0, _len = callbacks.length; _i < _len; _i++) {
                cb = callbacks[_i];
                if (!(cb === callback)) {
                  continue;
                }
                valid = true;
                break;
              }
              if (!valid) {
                throw "request supports no such callback '" + callback + "'";
              }
              return postMessage({
                id: id,
                params: params,
                callback: callback
              });
            },
            'error': function(error, message) {
              completed = true;
              if (!inTbl[id]) {
                throw "error called for nonexistent message: " + id;
              }
              delete inTbl[id];
              return postMessage({
                id: id,
                error: error,
                message: message
              });
            },
            'complete': function(v) {
              completed = true;
              if (!inTbl[id]) {
                throw "complete called for nonexistent message: " + id;
              }
              delete inTbl[id];
              return postMessage({
                id: id,
                'result': v
              });
            },
            'delayReturn': function(delay) {
              if (typeof delay === "boolean") {
                shouldDelayReturn = delay === true;
              }
              return shouldDelayReturn;
            },
            'completed': function() {
              return completed;
            }
          };
        };
        setTransactionTimeout = function(transId, timeout, method) {
          return root.setTimeout((function() {
            var msg;
            if (outTbl[transId]) {
              msg = "timeout (" + timeout + "ms) exceeded on method '" + method + "'";
              outTbl[transId].error("timeout_error", msg);
              delete outTbl[transId];
              return delete s_transIds[transId];
            }
          }), timeout);
        };
        onMessage = function(origin, method, m) {
          var cp, e, e2, error, id, message, obj, path, pathItems, resp, result, trans, _i, _j, _len, _len1, _ref, _ref1;
          if (typeof cfg.gotMessageObserver === "function") {
            try {
              cfg.gotMessageObserver(origin, m);
            } catch (_error) {
              e = _error;
              debug("gotMessageObserver() raised an exception: " + (e.toString()));
            }
          }
          if (m.id && method) {
            if (regTbl[method]) {
              trans = createTransaction(m.id, origin, (m.callbacks ? m.callbacks : []));
              inTbl[m.id] = {};
              try {
                if (m.callbacks && s_isArray(m.callbacks) && !m.callbacks.length) {
                  obj = m.params;
                  pathItems = path.split("/");
                  _ref = m.callbacks;
                  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                    path = _ref[_i];
                    _ref1 = pathItems.slice(0, -1);
                    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
                      cp = _ref1[_j];
                      if (typeof obj[cp] !== "object") {
                        obj[cp] = {};
                      }
                      obj = obj[cp];
                    }
                    obj[pathItems[pathItems.length - 1]] = (function() {
                      var cbName;
                      cbName = path;
                      return function(params) {
                        return trans.invoke(cbName, params);
                      };
                    })();
                  }
                }
                resp = regTbl[method](trans, m.params);
                if (!trans.delayReturn() && !trans.completed()) {
                  return trans.complete(resp);
                }
              } catch (_error) {
                e = _error;
                error = "runtime_error";
                message = null;
                if (typeof e === "string") {
                  message = e;
                } else if (typeof e === "object") {
                  if (e && s_isArray(e) && e.length === 2) {
                    error = e[0], message = e[1];
                  } else if (typeof e.error === "string") {
                    error = e.error;
                    if (!e.message) {
                      message = "";
                    } else if (typeof e.message === "string") {
                      message = e.message;
                    } else {
                      e = e.message;
                    }
                  }
                }
                if (message === null) {
                  try {
                    message = JSON.stringify(e);
                    if (typeof message === "undefined") {
                      message = e.toString();
                    }
                  } catch (_error) {
                    e2 = _error;
                    message = e.toString();
                  }
                }
                return trans.error(error, message);
              }
            }
          } else if (m.id && m.callback) {
            if (!outTbl[m.id] || !outTbl[m.id].callbacks || !outTbl[m.id].callbacks[m.callback]) {
              return debug("ignoring invalid callback, id: " + m.id + " (" + m.callback + ")");
            } else {
              return outTbl[m.id].callbacks[m.callback](m.params);
            }
          } else if (m.id) {
            if (!outTbl[m.id]) {
              return debug("ignoring invalid response: " + m.id);
            } else {
              error = m.error, message = m.message, id = m.id, result = m.result;
              if (error) {
                if (outTbl[id].error) {
                  outTbl[id].error(error, message);
                }
              } else {
                outTbl[id].success(result || null);
              }
              delete outTbl[id];
              return delete s_transIds[id];
            }
          } else if (method) {
            if (regTbl[method]) {
              return regTbl[method]({
                origin: origin
              }, m.params);
            }
          }
        };
        msg = typeof cfg.scope === "string" ? cfg.scope : '';
        s_addBoundChan(cfg.window, cfg.origin, msg, onMessage);
        scopeMethod = function(m) {
          if (typeof cfg.scope === "string" && cfg.scope.length) {
            m = [cfg.scope, m].join("::");
          }
          return m;
        };
        postMessage = function(msg, force) {
          var e, verb;
          if (!msg) {
            throw "postMessage called with null message";
          }
          verb = ready ? "post" : "queue";
          debug("" + verb + " message: " + (JSON.stringify(msg)));
          if (!force && !ready) {
            return pendingQueue.push(msg);
          } else {
            if (typeof cfg.postMessageObserver === "function") {
              try {
                cfg.postMessageObserver(cfg.origin, msg);
              } catch (_error) {
                e = _error;
                debug("postMessageObserver() raised an exception: " + (e.toString()));
              }
            }
            return cfg.window.postMessage(JSON.stringify(msg), cfg.origin);
          }
        };
        onReady = function(trans, type) {
          debug("ready msg received");
          if (ready) {
            throw "received ready message while in ready state. help!";
          }
          chanId += type === "ping" ? "-R" : "-L";
          obj.unbind("__ready");
          ready = true;
          debug("ready msg accepted.");
          if (type === "ping") {
            obj.notify({
              'method': "__ready",
              'params': "pong"
            });
          }
          while (pendingQueue.length) {
            postMessage(pendingQueue.pop());
          }
          if (typeof cfg.onReady === "function") {
            return cfg.onReady(obj);
          }
        };
        obj = {
          'unbind': function(method) {
            if (regTbl[method]) {
              if (!delete regTbl[method]) {
                throw "can't delete method: " + method;
              }
              return true;
            }
            return false;
          },
          'bind': function(method, cb) {
            if (!method || typeof method !== "string") {
              throw "'method' argument to bind must be string";
            }
            if (!cb || typeof cb !== "function") {
              throw "callback missing from bind params";
            }
            if (regTbl[method]) {
              throw "method '" + method + "' is already bound!";
            }
            regTbl[method] = cb;
            return this;
          },
          'call': function(m) {
            var callbackNames, callbacks, error, pruneFunctions, seen, success;
            if (!m) {
              throw "missing arguments to call function";
            }
            if (!m.method || typeof m.method !== "string") {
              throw "'method' argument to call must be string";
            }
            if (!m.success || typeof m.success !== "function") {
              throw "'success' callback missing from call";
            }
            if (!m.error || typeof m.error !== "function") {
              throw "'error' callback missing from call";
            }
            callbacks = {};
            callbackNames = [];
            seen = [];
            pruneFunctions = function(path, obj) {
              var k, np, _results;
              if (__indexOf.call(seen, obj) >= 0) {
                throw "params cannot be a recursive data structure";
              }
              seen.push(obj);
              if (typeof obj === "object") {
                _results = [];
                for (k in obj) {
                  if (!(obj.hasOwnProperty(k))) {
                    continue;
                  }
                  np = path + (path.length ? "/" : "") + k;
                  if (typeof obj[k] === "function") {
                    callbacks[np] = obj[k];
                    callbackNames.push(np);
                    _results.push(delete obj[k]);
                  } else {
                    if (typeof obj[k] === "object") {
                      _results.push(pruneFunctions(np, obj[k]));
                    } else {
                      _results.push(void 0);
                    }
                  }
                }
                return _results;
              }
            };
            pruneFunctions("", m.params);
            msg = {
              'id': s_curTranId,
              'method': scopeMethod(m.method),
              'params': m.params
            };
            if (callbackNames.length) {
              msg.callbacks = callbackNames;
            }
            if (m.timeout) {
              setTransactionTimeout(s_curTranId, m.timeout, scopeMethod(m.method));
            }
            error = m.error, success = m.success;
            outTbl[s_curTranId] = {
              callbacks: callbacks,
              error: error,
              success: success
            };
            s_transIds[s_curTranId] = onMessage;
            s_curTranId++;
            return postMessage(msg);
          },
          'notify': function(m) {
            if (!m) {
              throw "missing arguments to notify function";
            }
            if (!m.method || typeof m.method !== "string") {
              throw "'method' argument to notify must be string";
            }
            return postMessage({
              'method': scopeMethod(m.method),
              'params': m.params
            });
          },
          'destroy': function() {
            var scope;
            scope = typeof cfg.scope === 'string' ? cfg.scope : '';
            s_removeBoundChan(cfg.window, cfg.origin, scope);
            if ('removeEventListener' in root) {
              root.removeEventListener("message", onMessage, false);
            } else {
              if (root.detachEvent) {
                root.detachEvent("onmessage", onMessage);
              }
            }
            ready = false;
            regTbl = {};
            inTbl = {};
            outTbl = {};
            cfg.origin = null;
            pendingQueue = [];
            debug("channel destroyed");
            return chanId = "";
          }
        };
        obj.bind("__ready", onReady);
        setTimeout((function() {
          return postMessage({
            'method': scopeMethod("__ready"),
            'params': "ping"
          }, true);
        }), 0);
        return obj;
      }
    };
  })();

}).call(this);
