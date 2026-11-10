component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance("Helpers@ImageMagick");
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe("getDimensions()", () => {
            beforeEach(() => {
                setup();
            });

            it("Reads the dimensions of a jpg, png, and heic image", () => {
                expect(imageService.getDimensions(expandPath("/tests/resources/jpg_example.jpg"))).toBe({width: 200, height: 200});
                expect(imageService.getDimensions(expandPath("/tests/resources/png_example.png"))).toBe({width: 510, height: 361});
                expect(imageService.getDimensions(expandPath("/tests/resources/heic_example.heic"))).toBe({width: 1280, height: 720});
            });

            it("Throws for a file that is not actually a valid image", () => {
                expect(() => imageService.getDimensions(expandPath("/tests/resources/invalid_example.jpg"))).toThrow("ImageMagick.IdentifyException");
            });
        });
    }

}
