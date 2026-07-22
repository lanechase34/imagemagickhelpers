component {

    this.title       = 'Image Magick Helpers';
    this.author      = 'Chase Lane';
    this.webURL      = 'https://github.com/lanechase34/imagemagickhelpers';
    this.description = 'Helpers for interacting with ImageMagick';

    // Model Namespace
    this.modelNamespace = 'ImageMagickHelpers';

    // CF Mapping
    this.cfmapping = 'ImageMagickHelpers';

    // Dependencies - modules that must be loaded and activated before this one
    this.dependencies = ['cbvalidation'];

    /**
	 * Configure Module
	 */
    function configure() {
        settings = {
            cfmlEngine        : getCFMLEngine(),
            imageMagickPath   : getSystemSetting('IMAGEMAGICKPATH', ''), // Absolute path to the ImageMagick "magick" executable
            imageMagickTimeout: 30 // Max seconds cfexecute will wait on an ImageMagick call before timing out
        };

        // Add the image logger
        logBox = {
            appenders: {
                appLog: {
                    class     : 'coldbox.system.logging.appenders.RollingFileAppender',
                    properties: {
                        filePath       : '/logs',
                        filename       : 'app',
                        autoExpand     : false,
                        fileMaxSize    : 10000,
                        fileMaxArchives: 10,
                        async          : true
                    }
                }
            },
            categories: {
                Image: {
                    levelMin : 'FATAL',
                    levelMax : 'WARN',
                    appenders: 'appLog'
                }
            }
        };
    }

    /**
	 * Fired when the module is registered and activated.
	 */
    function onLoad() {
        // Injectable service layer
        binder
            .map(alias = ['Helpers@ImageMagick', '@ImageMagick'], force = true)
            .to('imagemagickhelpers.models.services.image')
            .initArg(name = 'cfmlEngine', value = settings.cfmlEngine)
            .initArg(name = 'imageMagickPath', value = settings.imageMagickPath)
            .initArg(name = 'imageMagickTimeout', value = settings.imageMagickTimeout);

        // Custom cbvalidation validators - used internally by service layer
        binder.map('fileExistsValidator@ImageMagick').to('imagemagickhelpers.models.validators.fileexists');
        binder.map('directoryExistsValidator@ImageMagick').to('imagemagickhelpers.models.validators.directoryexists');
        binder.map('noQuotesValidator@ImageMagick').to('imagemagickhelpers.models.validators.noquotes');
        binder.map('atLeastOneOfValidator@ImageMagick').to('imagemagickhelpers.models.validators.atleastoneof');
    }

    /**
	 * Fired when the module is unregistered and unloaded
	 */
    function onUnload() {
    }

    /**
     * Get the current CFML engine
     */
    function getCFMLEngine() {
        if(server.keyExists('boxlang')) {
            return 'boxlang';
        }
        else if(server.keyExists('lucee')) {
            return 'lucee';
        }
        else if(server.keyExists('coldfusion')) {
            return 'coldfusion';
        }
        throw('Invalid CFML engine detected');
    }

}
