component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance('Helpers@ImageMagick');
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe('verifyImageMagick()', () => {
            beforeEach(() => {
                setup();
            });

            it('Service can be created', () => {
                expect(imageService).toBeComponent();
            });

            it('Verifies ImageMagick is configured and functioning', () => {
                expect(() => imageService.verifyImageMagick()).notToThrow();
            });
        });
    }

}
