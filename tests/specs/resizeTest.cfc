component extends="tests.resources.baseTest" {

    function beforeAll() {
        super.beforeAll();
        imageService = getInstance('Helpers@ImageMagick');
    }

    function afterAll() {
        super.afterAll();
    }

    function run() {
        describe('resize()', () => {
            beforeEach(() => {
                setup();
            });

            it('Resizes to a single output using width only, preserving aspect ratio', () => {
                var dir     = newDir();
                var results = imageService.resize(
                    path    = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs = [{resizeDir: dir, width: 100}]
                );

                expect(results.len()).toBe(1);
                expect(fileExists(results[1])).toBeTrue();
                var dimensions = imageService.getDimensions(results[1]);
                expect(dimensions.width).toBe(100);
                expect(dimensions.height).toBe(100);
            });

            it('Resizes to a single output using height only, preserving aspect ratio, and strips a trailing slash from resizeDir', () => {
                var dir     = newDir();
                var results = imageService.resize(
                    path    = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs = [{resizeDir: dir & '/', height: 100}]
                );

                expect(results.len()).toBe(1);
                expect(fileExists(results[1])).toBeTrue();
                var dimensions = imageService.getDimensions(results[1]);
                expect(dimensions.width).toBe(100);
                expect(dimensions.height).toBe(100);
            });

            it('Resizes to a single output using both width and height, forcing exact dimensions and ignoring aspect ratio', () => {
                var dir     = newDir();
                var results = imageService.resize(
                    path    = expandPath('/tests/resources/png_example.png'),
                    outputs = [{resizeDir: dir, width: 50, height: 50}]
                );

                expect(results.len()).toBe(1);
                var dimensions = imageService.getDimensions(results[1]);
                expect(dimensions.width).toBe(50);
                expect(dimensions.height).toBe(50);
            });

            it('Resizes to multiple outputs in a single call, returning paths in order', () => {
                var dirA    = newDir();
                var dirB    = newDir();
                var results = imageService.resize(
                    path    = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs = [
                        {resizeDir: dirA, width: 80},
                        {resizeDir: dirB, height: 60}
                    ]
                );

                // resize() normalizes resizeDir to forward slashes before building the output path
                expect(results.len()).toBe(2);
                expect(results[1]).toBe(dirA.replace('\', '/', 'all') & '/jpg_example.jpg');
                expect(results[2]).toBe(dirB.replace('\', '/', 'all') & '/jpg_example.jpg');
                expect(fileExists(results[1])).toBeTrue();
                expect(fileExists(results[2])).toBeTrue();
            });

            it('Handles a source path using backslashes', () => {
                var dir         = newDir();
                var backslashed = replace(
                    expandPath('/tests/resources/jpg_example.jpg'),
                    '/',
                    '\',
                    'all'
                );
                var results = imageService.resize(path = backslashed, outputs = [{resizeDir: dir, width: 60}]);

                expect(results.len()).toBe(1);
                expect(fileExists(results[1])).toBeTrue();
            });

            it('Throws for an empty path', () => {
                expect(() => imageService.resize(path = '', outputs = [{resizeDir: newDir(), width: 100}])).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path that does not exist', () => {
                expect(() => imageService.resize(
                    path    = expandPath('/tests/resources/does_not_exist.jpg'),
                    outputs = [{resizeDir: newDir(), width: 100}]
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path containing a double-quote character', () => {
                expect(() => imageService.resize(
                    path    = '#expandPath('/tests/resources/jpg_example.jpg')#"; rm -rf /tmp',
                    outputs = [{resizeDir: newDir(), width: 100}]
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for an empty outputs array', () => {
                expect(() => imageService.resize(path = expandPath('/tests/resources/jpg_example.jpg'), outputs = [])).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws when an output is missing resizeDir', () => {
                expect(() => imageService.resize(
                    path    = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs = [{width: 100}]
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws when an output resizeDir does not exist', () => {
                expect(() => imageService.resize(
                    path    = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs = [{resizeDir: tempDir & '/does_not_exist_' & createUUID(), width: 100}]
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws when an output resizeDir contains a double-quote character', () => {
                expect(() => imageService.resize(
                    path    = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs = [{resizeDir: '#newDir()#"; rm -rf /tmp', width: 100}]
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws for a path using a UNC network path (SSRF/credential-leak via forced SMB auth)', () => {
                expect(() => imageService.resize(
                    path    = '\\attacker.test\share\evil.jpg',
                    outputs = [{resizeDir: newDir(), width: 100}]
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws when an output resizeDir is a UNC network path', () => {
                expect(() => imageService.resize(
                    path    = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs = [{resizeDir: '\\attacker.test\share', width: 100}]
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws when an output resizeDir starts with a pipe (ImageMagick PIPE coder command execution)', () => {
                expect(() => imageService.resize(
                    path    = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs = [{resizeDir: '|touch /tmp/pwned', width: 100}]
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws when an output is missing both width and height', () => {
                expect(() => imageService.resize(
                    path    = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs = [{resizeDir: newDir()}]
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws when an output width is not positive', () => {
                expect(() => imageService.resize(
                    path    = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs = [{resizeDir: newDir(), width: 0}]
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws when an output height is not positive', () => {
                expect(() => imageService.resize(
                    path    = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs = [{resizeDir: newDir(), height: -10}]
                )).toThrow('ImageMagick.InputValidationException');
            });

            it('Throws ImageMagick.ResizeException when ImageMagick fails to produce an output', () => {
                expect(() => imageService.resize(
                    path    = expandPath('/tests/resources/invalid_example.jpg'),
                    outputs = [{resizeDir: newDir(), width: 100}]
                )).toThrow('ImageMagick.ResizeException');
            });

            it('Cleans up previously-resized outputs when a later output fails', () => {
                var dirA = newDir();
                var dirB = newDir();

                // Pre-create a directory at the exact path ImageMagick would need to write dirB's output
                // file to, forcing that second output to fail while the first output succeeds
                directoryCreate(dirB & '/jpg_example.jpg');

                var expectedSuccessPath = dirA & '/jpg_example.jpg';

                expect(() => imageService.resize(
                    path    = expandPath('/tests/resources/jpg_example.jpg'),
                    outputs = [
                        {resizeDir: dirA, width: 100},
                        {resizeDir: dirB, width: 100}
                    ]
                )).toThrow('ImageMagick.ResizeException');

                expect(fileExists(expectedSuccessPath)).toBeFalse();
            });
        });
    }

}
