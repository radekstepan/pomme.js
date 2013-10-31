_     = require 'lodash'
async = require 'async'
glob  = require 'glob'
path  = require 'path'
fs    = require 'fs'

eco = require 'eco'
cs  = require 'coffee-script'

dir = __dirname

# Load moulds.
moulds = {} ; ready = no ; callbacks = []

async.waterfall [ (cb) ->
    glob dir + '/moulds/**/*.eco.js', cb

, (files, cb) ->
    # Process in parallel.
    async.each files, (file, cb) ->
        # Is it a file?
        fs.stat file, (err, stats) ->
            return cb err if err

            # Skip directories.
            return cb null unless do stats.isFile

            # Read the mould.
            fs.readFile file, 'utf8', (err, mould) ->
                return cb err if err

                # Get a relative from the file.
                pointer = moulds
                for i, part of parts = file.match(/moulds\/(.*)\.eco\.js$/)[1].split('/')
                    if parts.length is +i + 1
                        # Make into an Eco function.
                        pointer[part] = (context) ->
                            eco.render mould, context
                    else
                        pointer = pointer[part] ?= {}

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

        # Remove the extension. It will be a `.js` one.
        opts.main = opts.main.split('.')[0...-1].join('.')

        # For each source.
        async.map sources, (source, cb) ->
            # Find the handler.
            unless handler = handlers[ext = path.extname(source)[1...]] # sans dot
                return cb "Unrecognized file extension #{ext.bold}"

            # Run the handler.
            handler source, (err, result) ->
                return cb err if err

                # Wrap it in the module registry.
                cb null, moulds.commonjs.module
                    'package': pkg.name
                    'path': source
                    'script': moulds.lines
                        'spaces': 2
                        'lines': result

        # Merge it into a destination file.
        , (err, modules) ->
            return cb err if err

            # Nicely format the modules.
            modules = _.map modules, (module) ->
                moulds.lines 'spaces': 4, 'lines': module

            # Write a vanilla version and one packing a requirerer.
            async.each [ 'require', 'vanilla' ], (variant, cb) ->
                out = moulds.commonjs[variant]
                    'modules': modules
                    'package': pkg.name
                    'main': opts.main

                # Inject a suffix.
                filename = destination.replace /\.([^\.]*)$/, ".#{variant}.$1"

                # Write it.
                fs.writeFile filename, out, cb

            , cb
    
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