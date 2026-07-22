component {

    this.name = 'ImageMagickHelpers Testing';

    this.mappings['/tests'] = getDirectoryFromPath(getCurrentTemplatePath());
    rootPath                = reReplaceNoCase(this.mappings['/tests'], 'tests(\\|/)', '');

    this.mappings['/root']       = rootPath;
    this.mappings['/moduleroot'] = rootPath & '../';
    this.mappings['/testbox']    = rootPath & 'modules/testbox';

    COLDBOX_APP_ROOT_PATH = rootPath;
    COLDBOX_APP_MAPPING   = 'root';
    COLDBOX_CONFIG_FILE   = '';
    COLDBOX_APP_KEY       = '';

    public boolean function onApplicationStart() {
        // We need the full coldbox bootstrap for e2e integration test
        application.cbBootstrap = new coldbox.system.Bootstrap(
            COLDBOX_CONFIG_FILE,
            COLDBOX_APP_ROOT_PATH,
            COLDBOX_APP_KEY,
            COLDBOX_APP_MAPPING
        );
        application.cbBootstrap.loadColdbox();
        return true;
    }

    public boolean function onRequestStart(String targetPage) {
        setting requestTimeout="9999";

        // Treat this as the real coldbox running application for full e2e integration tests
        if(getFileFromPath(arguments.targetPage) == 'index.cfm') {
            application.cbBootstrap.onRequestStart(arguments.targetPage);
        }
        // Virtual coldbox application for tests
        else {
            request.coldBoxVirtualApp = new coldbox.system.testing.VirtualApp(appMapping = '/root');
            request.coldBoxVirtualApp.startup(true);
        }

        return true;
    }

    public void function onRequestEnd(targetPage) {
        if(request.keyExists('coldBoxVirtualApp')) {
            request.coldBoxVirtualApp.shutdown();
        }
    }

}
