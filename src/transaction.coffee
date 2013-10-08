# One transaction.
class Transaction

    completed: no

    constructor: (@id, @origin, @callbacks, @channel) ->
        @channel.inTbl[@id] = {}
            
    invoke: (callback, params) =>
        # verify in table
        throw "attempting to invoke a callback of a nonexistent transaction: #{@id}" unless @channel.inTbl[@id]
        
        # verify that the callback name is valid
        if do ( -> ( return yes for cb in @callbacks when cb is callback ) )
            # send callback invocation
            @channel.postMessage { @id, params, callback }
        else
            throw "request supports no such callback '#{callback}'"

    error: (error, message) =>
        @completed = yes
        
        # verify in table
        throw "error called for nonexistent message: #{@id}" unless @channel.inTbl[@id]
        
        # remove transaction from table
        delete @channel.inTbl[@id]
        
        # send error
        @channel.postMessage { @id, error, message }

    complete: (result) =>
        @completed = yes
        
        # verify in table
        throw "complete called for nonexistent message: #{@id}" unless @channel.inTbl[@id]
        
        # remove transaction from table
        delete @channel.inTbl[@id]

        # send complete
        @channel.postMessage { @id, result }

module.exports = Transaction