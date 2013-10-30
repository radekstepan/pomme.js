_     = require 'lodash'
async = require 'async'
path  = require 'path'
fs    = require 'fs'

eco = require 'eco'
cs  = require 'coffee-script'

dir = __dirname

# Load moulds.
moulds = {} ; ready = no ; callbacks = []

async.waterfall [ (cb) ->
    fs.readdir dir + '/moulds', cb

, (files, cb) ->
    async.each files, (file, cb) ->
        fs.readFile dir + '/moulds/' + file, 'utf8', (err, mould) ->
            return cb err if err
            
            # Make into an Eco function.
            moulds[file.split('.')[0]] = (context) ->
                eco.render mould, context
            
            cb null
    , cb

], (err) ->
    # Trouble?
    process.exit(1) if err

    # Dequeue.
    ready = yes
    ( do cb for cb in callbacks )

# The keys represent the file extensions.
handlers =
    # Handle CoffeeScript.
    coffee: (filepath, cb) ->
        fs.readFile filepath, 'utf8', (err, src) ->
            try
                js = cs.compile src, 'bare': 'on'
                cb null, js
            catch err
                cb err

    # Handle a generic file (JavaScript).
    js: (filepath, cb) ->
        fs.readFile filepath, 'utf8', cb

    # Handle Eco templates.
    eco: (filepath, cb) ->
        async.waterfall [ (cb) ->
            fs.readFile filepath, 'utf8', cb

        , (src, cb) ->
            try
                template = eco.precompile src
                return cb null, 'module.exports = ' + template
            catch err
                return cb err
        ], cb

commonjs = (grunt, cb) ->
    # What is the name of the package.
    pkg = grunt.config.data.pkg.name

    # For each in/out config.
    async.each @files, (file, cb) ->
        sources     = file.src
        destination = path.normalize file.dest

        # Find all index files.
        rule = /index\.(coffee|js)$/
        unless (idx = _(sources)
        .filter((source) ->
            # Coffee and JS files supported.
            source.match rule
        ).sort((a, b) ->
            score = (input) -> input.split('/').length
            score(a) - score(b)
        ).value()).length
            return cb "Main `#{rule}` file not found"

        # Get the closest index file to the root.
        main = idx[0]

        # For each source.
        async.map sources, (source, cb) ->
            # Find the handler.
            unless handler = handlers[ext = path.extname(source)[1...]] # sans dot
                return cb "Unrecognized file extension `#{ext}`"

            # Run the handler.
            handler source, (err, result) ->
                return cb err if err

                # Wrap it in the module registry.
                cb null, moulds.module
                    'package': pkg
                    'path': source
                    'script': moulds.lines
                        'spaces': 4
                        'lines': result

        # Merge it into a destination file.
        , (err, modules) ->
            return cb err if err

            modules = _.map modules, (module) ->
                moulds.lines 'spaces': 4, 'lines': module

            # Wrap in CommonJS.
            content = moulds.require { modules }

            # Expose to the outside world.
            out = moulds.wrapper
                'package': pkg
                'main': main.split('.')[0...-1].join('.')
                'content': moulds.lines
                    'spaces': 4
                    'lines': content

            # Write it.
            fs.writeFile destination, out, cb
    
    , cb

module.exports = (grunt) ->
    grunt.registerMultiTask 'apps_c', 'Apps/C - CoffeeScript, JavaScript, Eco', ->
        # Run in async.
        done = do @async

        # Wrapper for error logging.
        cb = (err) ->
            if err
                grunt.log.error do err.toString
                done false
            else
                grunt.log.writeln 'Done'
                do done

        # Once our builder is ready...
        onReady = =>
            # The targets we support.
            switch @target
                when 'commonjs'
                    commonjs.apply @, [ grunt, cb ]
                else
                    cb "Unsupported target `#{@target}`"

        # Hold your horses?
        return do onReady if ready
        callbacks.push onReady