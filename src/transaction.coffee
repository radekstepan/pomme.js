# One transaction.
class Transaction

    completed: no

    constructor: (@id, @origin, @callbacks, @channel) ->
        @channel.incoming[@id] = {}
            
    invoke: (callback, params) =>
        # verify in table
        throw "attempting to invoke a callback of a nonexistent transaction: #{@id}" unless @channel.incoming[@id]
        
        # verify that the callback name is valid
        if do ( -> ( return yes for cb in @callbacks when cb is callback ) )
            # send callback invocation
            @channel.postMessage { @id, params, callback }
        else
            throw "request supports no such callback '#{callback}'"

    error: (error, message) =>
        @completed = yes
        
        # verify in table
        throw "error called for nonexistent message: #{@id}" unless @channel.incoming[@id]
        
        # remove transaction from table
        delete @channel.incoming[@id]
        
        # send error
        @channel.postMessage { @id, error, message }

    complete: (result) =>
        return if @completed

        @completed = yes
        
        # verify in table
        throw "complete called for nonexistent message: #{@id}" unless @channel.incoming[@id]
        
        # remove transaction from table
        delete @channel.incoming[@id]

        # send complete
        @channel.postMessage { @id, result }

module.exports = Transaction