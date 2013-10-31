module.exports = (grunt) ->
    grunt.initConfig
        pkg: grunt.file.readJSON("package.json")
        
        apps_c:
            commonjs:
                src: [ 'src/**/*.{coffee,js,eco}' ]
                dest: 'build/app.commonjs.js'
                options:
                    main: 'src/index.js'

    grunt.loadTasks('tasks')

    grunt.registerTask('default', [ 'apps_c' ])