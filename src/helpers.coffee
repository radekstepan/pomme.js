root = window

module.exports =

    'nextTick': do ->
        switch
            # setImmediate.
            when 'setImmediate' of root and _.isFunction root.setImmediate
                (f) -> setImmediate f

            # setTimeout.
            when typeof(root) is 'undefined' or 'ActiveXObject' of root or not 'postMessage' of root
                (f) -> setTimeout f

            # postMessage.
            else
                # Functions to run.
                fns = []
                
                tick = -> root.postMessage 'tick', '*'

                # Listen to messages.
                root.addEventListener 'message', ->
                    # Do we have functions?
                    while fns.length
                        fn = do fns.shift
                        try
                            do fn
                        catch err
                            do tick
                            throw err
                , yes
                
                (fn) ->
                    do tick unless fns.length
                    fns.push fn