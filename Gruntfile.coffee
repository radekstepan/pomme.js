module.exports = (grunt) ->
    grunt.initConfig
        pkg: grunt.file.readJSON("package.json")
        
        apps_c:
            commonjs:
                src: [ 'src/**/*.{coffee,js,eco}' ]
                dest: 'build/app.commonjs.js'
                options:
                    main: 'src/index.js'

        concat:
            options:
                separator: ';' # we will minify...
            dist:
                src: [
                    # Vendor dependencies.
                    'vendor/lodash/dist/lodash.js'
                    'vendor/cryo/lib/cryo.js'
                    # Our app with requirerer.
                    'build/app.commonjs.require.js'
                ]
                dest: 'build/app.commonjs.bundle.js'

        uglify:
            my_target:
                files:
                    'build/app.commonjs.bundle.min.js': 'build/app.commonjs.bundle.js'
                    'build/app.commonjs.require.min.js': 'build/app.commonjs.require.js'
                    'build/app.commonjs.vanilla.min.js': 'build/app.commonjs.vanilla.js'

    grunt.loadTasks('tasks')

    grunt.loadNpmTasks('grunt-contrib-concat')
    grunt.loadNpmTasks('grunt-contrib-uglify')

    grunt.registerTask('default', [ 'apps_c', 'concat', 'uglify' ])