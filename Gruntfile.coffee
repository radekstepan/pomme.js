module.exports = (grunt) ->
    grunt.initConfig
        pkg: grunt.file.readJSON("package.json")
        
        apps_c:
            commonjs:
                src: [ 'src/**/*.{coffee,js,eco}' ]
                dest: 'build/app.js'
                options:
                    name: [
                        'pomme.js'
                        'Pomme.js'
                        'pommejs'
                        'PommeJS'
                        'pomme'
                        'Pomme'
                    ]
                    main: 'src/channel.coffee'

        concat:
            options:
                separator: ';' # we will minify...
            dist:
                src: [
                    # Vendor dependencies.
                    'vendor/underscore/underscore.js'
                    # Our app with requirerer.
                    'build/app.js'
                ]
                dest: 'build/app.bundle.js'

        uglify:
            my_target:
                files:
                    'build/app.min.js': 'build/app.js'
                    'build/app.bundle.min.js': 'build/app.bundle.js'

        coffeelint:
            app:
                src: [ 'src/**/*.coffee' ]
                options:
                    indentation:
                        'level': 'ignore'


    grunt.loadNpmTasks('grunt-apps-c')
    grunt.loadNpmTasks('grunt-contrib-concat')
    grunt.loadNpmTasks('grunt-contrib-uglify')
    grunt.loadNpmTasks('grunt-coffeelint')

    grunt.registerTask('default', [
        #'coffeelint'
        'apps_c'
        'concat'
        'uglify'
    ])