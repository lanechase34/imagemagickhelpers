component {

	/**
	 * Configure ColdBox for the test-only virtual app
	 */
	function configure() {
		coldbox = {
			appName                : 'ImageMagickHelpers Tester',
			reinitPassword          : '',
			handlersIndexAutoReload : true,
			modulesExternalLocation : [],
			defaultEvent            : '',
			customErrorTemplate     : '/coldbox/system/exceptions/Whoops.cfm',
			handlerCaching          : false,
			eventCaching            : false
		};

		modules = {
			include: [],
			exclude: []
		};

		// Keep test-only handlers under tests/ instead of polluting the published module package
		conventions = {
			handlersLocation: 'tests/handlers'
		};

		interceptors = [];

		logBox = {
			appenders: {
				console: {class: 'ConsoleAppender'}
			},
			root: {levelmax: 'DEBUG', appenders: '*'}
		};
	}

	/**
	 * Register and activate our own module once the rest of ColdBox has finished loading
	 */
	function afterAspectsLoad(event, interceptData, rc, prc) {
		controller.getModuleService().registerAndActivateModule(
			moduleName     : 'imagemagickhelpers',
			invocationPath : 'moduleroot'
		);
	}

}
