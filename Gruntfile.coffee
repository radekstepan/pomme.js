module.exports = (grunt) ->
    grunt.initConfig
        pkg: grunt.file.readJSON("package.json")
        
        apps_c:
            commonjs:
                # http://gruntjs.com/configuring-tasks#files
                # https://github.com/gruntjs/grunt/wiki/Configuring-tasks#globbing-patterns
                src: [ 'src/**/*.{coffee,js,eco}' ]
                dest: 'build/app.js'

    grunt.loadTasks('tasks')

    grunt.registerTask('default', [ 'apps_c' ])