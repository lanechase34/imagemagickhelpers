component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance('Helpers@ImageMagick');
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe('validIdentify()', () => {
            beforeEach(() => {
                setup();
            });

            it('Valid identifies a heic image', () => {
                expect(() => imageService.validIdentify(expandPath('/tests/resources/heic_example.heic'))).notToThrow();
            });

            it('Valid identifies a jpg image', () => {
                expect(() => imageService.validIdentify(expandPath('/tests/resources/jpg_example.jpg'))).notToThrow();
            });

            it('Valid identifies a jpeg image', () => {
                expect(() => imageService.validIdentify(expandPath('/tests/resources/jpeg_example.jpeg'))).notToThrow();
            });

            it('Valid identifies a png image', () => {
                expect(() => imageService.validIdentify(expandPath('/tests/resources/png_example.png'))).notToThrow();
            });

            it('Throws for a file that is not actually a valid image', () => {
                expect(() => imageService.validIdentify(expandPath('/tests/resources/invalid_example.jpg'))).toThrow('ImageMagick.IdentifyException');
            });

            it('Throws for an empty path', () => {
                expect(() => imageService.validIdentify('')).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path that does not exist', () => {
                expect(() => imageService.validIdentify(expandPath('/tests/resources/does_not_exist.jpg'))).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path containing a double-quote character', () => {
                expect(() => imageService.validIdentify('#expandPath('/tests/resources/jpg_example.jpg')#"; rm -rf /tmp')).toThrow('ImageMagick.InputValidationException');
            });
        });
    }

}
