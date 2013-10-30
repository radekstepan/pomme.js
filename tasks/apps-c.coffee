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
    pkg = grunt.config.data.pkg

    # For each in/out config.
    async.each @files, (file, cb) =>
        sources     = file.src
        destination = path.normalize file.dest

        # Any opts?
        opts = @options
            'main': do ->
                # A) Use the main file in `package.json`.
                return pkg.main if pkg.main

                # B) Find the index file closest to the root.
                _(sources)
                .filter((source) ->
                    # Coffee and JS files supported.
                    source.match /index\.(coffee|js)$/
                ).sort((a, b) ->
                    score = (input) -> input.split('/').length
                    score(a) - score(b)
                ).value()[0]

        # Not null?
        return cb 'Main index file not defined' unless opts.main

        # Does the index file actually exist?
        return cb "Main index file #{opts.main.bold} does not exist" unless opts.main in sources

        # Say we use this index file.
        grunt.log.writeln "Using index file #{opts.main.bold}".yellow

        # For each source.
        async.map sources, (source, cb) ->
            # Find the handler.
            unless handler = handlers[ext = path.extname(source)[1...]] # sans dot
                return cb "Unrecognized file extension #{ext.bold}"

            # Run the handler.
            handler source, (err, result) ->
                return cb err if err

                # Wrap it in the module registry.
                cb null, moulds.module
                    'package': pkg.name
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
                'package': pkg.name
                'main': opts.main.split('.')[0...-1].join('.')
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
            return do done unless err
            grunt.log.error (do err.toString).red
            done false

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