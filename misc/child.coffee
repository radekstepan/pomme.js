# Build a channel with our parent.
channel = new Samskipti 'B',
    'window': window.parent
    'origin': '*'
    'scope': 'steps'

# Someone wants an app built?
channel.listenOn.apps = (name, config) ->
    load = ->
        # New instance.
        apps = new intermine.appsA document.location.href.replace('/iframe.html', '')
        # Load it.
        apps.load name, 'body', config

    # Do we need to load apps?
    return load.call null if intermine.appsA

    # Need to load the deps first.
    get 'apps-a', (err) ->
        throw err if err
        load.call null

# Results tables.
channel.listenOn.imtables = (config) ->
    # Load the table into the body.
    load = ->
        # IMJS.
        config.service = new intermine.Service
            'root': config.mine
            'token': config.token
            'errorHandler': (err) ->
                throw err if err

        # A `table` by default.
        config.type ?= 'table'
        # Go.
        $('body').imWidget(config)

    # Do we need to load bundle?
    return load.call null if $?.imWidget

    # Need to load the deps first.
    get 'imtables', (err) ->
        throw err if err
        # Now load them.
        load.call null

# List widgets.
channel.listenOn.widgets = (config) ->
    # Load the widget to the body.
    load = ->
        # New instance.
        widgets = new intermine.widgets
            'root': config.mine + '/service/'
            'token': config.token
            'skipDeps': yes

        # Load it (do not care for callbacks atmo).
        widgets[config.type] config.id, config.list, 'body', {}

    # Do we need to load list widgets?
    return load.call null if intermine.widgets

    # Need to load the deps first.
    get 'widgets', (err) ->
        throw err if err
        load.call null


# Bundles for API Loader that already exists on the page.
bundles =
# Apps/A.
'apps-a':
    'js':
        'intermine.apps-a':
            path: '/iframe/js/intermine/intermine.apps-a-1.2.0.js'

# Results Tables Bundle.
'imtables':
    'css':
        'whateva1':
            path: '/iframe/css/bootstrap-2.0.4.css'
        'whateva2':
            path: '/iframe/css/intermine/imtables-1.3.0.css'
    'js':
        '_':
            path: '/iframe/js/lodash.underscore-1.2.1.js'
        'jQuery':
            path: '/iframe/js/jquery-1.9.1.js'
        'jQuery.imWidget':
            path: '/iframe/js/intermine/imtables-mini-bundle-1.3.0.js'
            depends: [ 'intermine.imjs' ]
        'intermine.imjs':
            path: '/iframe/js/intermine/im-2.5.1.js'
            depends: [ 'jQuery', '_' ]
        'Backbone':
            path: '/iframe/js/backbone-1.0.0.js'
            depends: [ 'jQuery', '_' ]

# List Widgets.
'widgets':
    'css':
        'whateva1':
            path: '/iframe/css/bootstrap-2.0.4.css'
    'js':
        'intermine.widgets':
            path: '/iframe/js/intermine/intermine.widgets-1.12.8.js'
        'setImmediate':
            path: '/iframe/js/setImmediate.js'
        'async':
            path: '/iframe/js/async-0.2.6.js'
            depends: [ 'setImmediate' ]
        'jQuery':
            path: '/iframe/js/jquery-1.9.1.js'
        '_':
            path: '/iframe/js/lodash.underscore-1.2.1.js'
        'Backbone':
            path: '/iframe/js/backbone-1.0.0.js'
            depends: [ 'jQuery', '_' ]
        'google':
            path: 'https://www.google.com/jsapi'
        'intermine.imjs':
            path: '/iframe/js/intermine/im-2.5.1.js'
            depends: [ 'jQuery', '_' ]
        'FileSaver':
            path: '/iframe/js/fileSaver.js'

# Get a bundle and call back.
get = (bundle, cb) -> intermine.load bundles[bundle], cb