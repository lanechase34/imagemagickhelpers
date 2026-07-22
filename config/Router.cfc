component {

    function configure() {
        setFullRewrites(true);

        post('/upload', 'upload.uploadFile');
    }

}
