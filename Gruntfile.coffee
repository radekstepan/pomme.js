module.exports = (grunt) ->
    grunt.initConfig
        pkg: grunt.file.readJSON("package.json")
        
        apps_c:
            commonjs:
                src: [ 'src/**/*.{coffee,js,eco}' ]
                dest: 'build/app.js'
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
                    'build/app.js'
                ]
                dest: 'build/app.bundle.js'

        uglify:
            my_target:
                files:
                    'build/app.min.js': 'build/app.js'
                    'build/app.bundle.min.js': 'build/app.bundle.js'


    grunt.loadNpmTasks('grunt-apps-c')
    grunt.loadNpmTasks('grunt-contrib-concat')
    grunt.loadNpmTasks('grunt-contrib-uglify')

    grunt.registerTask('default', [ 'apps_c', 'concat', 'uglify' ])