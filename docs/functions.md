# Image Service Functions

Reference for every public function on the `Helpers@ImageMagick` service (`models/services/image.cfc`). Inject it with:

```cfc
property name="imageService" inject="Helpers@ImageMagick";
```

All functions validate their arguments before doing any work and throw `ImageMagick.InputValidationException` if a constraint is violated (missing required argument, unsafe or non-existent path, a quality outside 1-100, a width/height under 1px, etc). See each function below for the additional, function-specific exceptions it can throw.

Every exception's `message` says what failed, and its `detail` holds the technical cause (ex: ImageMagick's error output). `ImageMagick.UploadValidationException` messages are written to be shown to end users as is (ex: `"Image is too large - it can be at most 100 megapixels."`) - log `detail`, but don't show it to users.

Functions that write files have ImageMagick write into a temp directory first, and only move the results to their output paths once every output was written. A failed run writes and replaces nothing - any file already at an output path is left as it was, even when the output path is the source itself. (The one exception: if moving a result into place fails, ex: permissions, the results already moved stay, and the file being replaced at the failed path may already be gone.) Every ImageMagick call runs with the configured [resource limits](../README.md#configuration).

**Supported extensions** (for upload `extensions` and output `type`): `png`, `jpg`, `jpeg`, `webp`, `heic`, `gif`, `bmp`, `tif`, `tiff`, `svg`, `avif`, `ico` - as long as your ImageMagick build can read (sources) or write (outputs) that format. Many builds can read HEIC but not write it, see [Supported Formats](../README.md#supported-formats).

## Table of Contents

- [verifyImageMagick()](#verifyimagemagick)
- [identify(path)](#identifypath)
- [getDimensions(path)](#getdimensionspath)
- [convert(path, outputPath, quality, resize, strip, autoOrient)](#convertpath-outputpath-quality-resize-strip-autoorient)
- [crop(path, outputPath, width, height, strip, autoOrient)](#croppath-outputpath-width-height-strip-autoorient)
- [autoOrient(path, outputPath)](#autoorientpath-outputpath)
- [resize(path, outputs, strip, autoOrient)](#resizepath-outputs-strip-autoorient)
- [validateUpload(formField, outputs, extensions, strip, autoOrient, maxPixels, maxFileSize, quality, resize)](#validateuploadformfield-outputs-extensions-strip-autoorient-maxpixels-maxfilesize-quality-resize)

---

## verifyImageMagick()

Checks that the configured `imageMagickPath` points to a working ImageMagick install by running `magick -version` and confirming it returns output. Useful as a startup/health check.

**Arguments:** none

**Returns:** nothing (`void`)

**Throws**

- `ImageMagick.VerificationException` - ImageMagick could not be reached, or did not return version information

**Example**

```cfc
imageService.verifyImageMagick();
```

---

## identify(path)

Runs ImageMagick `identify` against `path` to confirm the file is a real, readable image (not just a file with an image-like extension) and returns the coder/format ImageMagick itself detected for its first frame - based on the file's actual content, not its extension. The image is fully decoded, so a file with a valid header but corrupt pixel data is rejected.

**Arguments**

| Name | Type   | Required | Description                     |
| ---- | ------ | -------- | ------------------------------- |
| path | string | yes      | Full path to the image to check |

**Returns:** string - ImageMagick's uppercased format name for `path` (ex: `'PNG'`, `'JPEG'`)

**Throws**

- `ImageMagick.InputValidationException` - `path` is empty or does not exist
- `ImageMagick.IdentifyException` - ImageMagick reports `path` is not a valid image

**Example**

```cfc
var format = imageService.identify('/tmp/uploads/photo.jpg');
// format = "JPEG"
```

---

## getDimensions(path)

Reads the pixel width/height of an image's first frame. Only the image header is read (`identify -ping`), so this is fast even for very large images.

**Arguments**

| Name | Type   | Required | Description                     |
| ---- | ------ | -------- | ------------------------------- |
| path | string | yes      | Full path to the image to check |

**Returns:** struct - `{width: numeric, height: numeric}` in pixels

**Throws**

- `ImageMagick.InputValidationException` - `path` is empty or does not exist
- `ImageMagick.IdentifyException` - ImageMagick failed to report dimensions for `path`

**Example**

```cfc
var dimensions = imageService.getDimensions('/tmp/uploads/photo.jpg');
// dimensions = {width: 1920, height: 1080}
```

---

## convert(path, outputPath, quality, resize, strip, autoOrient)

Adjusts quality and shrink-to-fits the source image, writing the result to `outputPath`. The output format is determined by `outputPath`'s extension. Only shrinks the image if it exceeds `resize` - images already smaller than that bound are left at their original dimensions.

By default metadata is stripped, which also discards any EXIF orientation tag - pass `autoOrient = true` to bake that orientation into the pixels first (the same rotation as [`autoOrient()`](#autoorientpath-outputpath), in a single pass). With `strip = false` and `autoOrient = true`, metadata is kept and the orientation tag is reset to normal so viewers don't rotate the image a second time.

**Arguments**

| Name       | Type    | Required | Default | Description                                                        |
| ---------- | ------- | -------- | ------- | ------------------------------------------------------------------ |
| path       | string  | yes      | -       | Full path to source image                                          |
| outputPath | string  | yes      | -       | Full path to output file, including extension                      |
| quality    | numeric | no       | `50`    | 1-100 output quality                                               |
| resize     | numeric | no       | `1200`  | Max width/height in pixels to shrink to                            |
| strip      | boolean | no       | `true`  | Whether to strip metadata (EXIF, ICC profiles, etc) from the image |
| autoOrient | boolean | no       | `false` | Rotate/flip upright using the image's EXIF orientation tag         |

**Returns:** nothing (`void`)

**Throws**

- `ImageMagick.InputValidationException` - `path` does not exist, `outputPath` is empty, `quality` is not between 1 and 100, or `resize` is less than 1
- `ImageMagick.ConversionException` - ImageMagick failed to produce the converted output

**Example**

```cfc
imageService.convert(
    path       = '/tmp/uploads/photo.jpg',
    outputPath = '/var/www/images/photo.webp',
    quality    = 75,
    resize     = 1600,
    autoOrient = true
);
```

---

## crop(path, outputPath, width, height, strip, autoOrient)

Crops the source image to exact `width`x`height` dimensions: scales the image to fully cover the target box (preserving aspect ratio) then crops the overflow from the center. Unlike [`resize()`](#resizepath-outputs-strip-autoorient)'s forced-dimensions mode, this never distorts the image.

**Arguments**

| Name       | Type    | Required | Default | Description                                                         |
| ---------- | ------- | -------- | ------- | ------------------------------------------------------------------- |
| path       | string  | yes      | -       | Full path to source image                                           |
| outputPath | string  | yes      | -       | Full path to output file, including extension                       |
| width      | numeric | yes      | -       | Target width in pixels                                              |
| height     | numeric | yes      | -       | Target height in pixels                                             |
| strip      | boolean | no       | `true`  | Whether to strip metadata (EXIF, ICC profiles, etc) from the image  |
| autoOrient | boolean | no       | `false` | Rotate/flip upright using the image's EXIF orientation before crop |

**Returns:** nothing (`void`)

**Throws**

- `ImageMagick.InputValidationException` - `path` does not exist, `outputPath` is empty, or `width`/`height` is less than 1
- `ImageMagick.CropException` - ImageMagick failed to produce the cropped output

**Example**

```cfc
imageService.crop(
    path       = '/var/www/images/photo.jpg',
    outputPath = '/var/www/images/photo_thumb.jpg',
    width      = 300,
    height     = 300,
    autoOrient = true
);
```

---

## autoOrient(path, outputPath)

Physically rotates/flips the image according to its EXIF orientation tag and resets that tag to normal, writing the result to `outputPath`. Photos uploaded directly from phone cameras are frequently stored sideways/upside-down with only an EXIF flag marking the correct orientation - most browsers and image libraries ignore that flag, so this bakes the correct orientation into the pixels.

To orient as part of another operation instead, pass `autoOrient = true` to `convert()`, `crop()`, `resize()`, or `validateUpload()`.

HEIC images (ex: iPhone photos) store their rotation in the HEIF container as well as the EXIF tag. ImageMagick's HEIC decoder applies that rotation as it reads the image and marks it upright, so a HEIC comes out upright with or without `autoOrient`, and is never rotated twice.

**Arguments**

| Name       | Type   | Required | Description                                   |
| ---------- | ------ | -------- | --------------------------------------------- |
| path       | string | yes      | Full path to source image                     |
| outputPath | string | yes      | Full path to output file, including extension |

**Returns:** nothing (`void`)

**Throws**

- `ImageMagick.InputValidationException` - `path` does not exist or `outputPath` is empty
- `ImageMagick.OrientException` - ImageMagick failed to produce the oriented output

**Example**

```cfc
imageService.autoOrient(
    path       = '/tmp/uploads/phone_photo.jpg',
    outputPath = '/tmp/uploads/phone_photo_fixed.jpg'
);
```

---

## resize(path, outputs, strip, autoOrient)

Resizes the source image to one or more output sizes in a single call, decoding the source only once. If both `width` and `height` are given for an output, the image is forced to those exact dimensions (aspect ratio ignored). If only one is given, the image is scaled to that dimension with aspect ratio preserved. Each output's destination filename matches the source filename, placed in that output's `resizeDir` - so every output must use a different `resizeDir` - and is written in the source's format, so a HEIC source needs an ImageMagick build that can write HEIC (convert it first otherwise). If a resized file already exists at the destination, it is intentionally replaced - but only once every output succeeded. If any output fails, no output is written or replaced.

**Arguments**

| Name       | Type    | Required | Default | Description                                                                                                                                                                                 |
| ---------- | ------- | -------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| path       | string  | yes      | -       | Full path to source image                                                                                                                                                                   |
| outputs    | array   | yes      | -       | Array of structs (1-10), each `{resizeDir: string, width: numeric, height: numeric}`. `resizeDir` is required and must be unique per entry; at least one of `width`/`height` is required |
| strip      | boolean | no       | `true`  | Whether to strip metadata (EXIF, ICC profiles, etc) from each resized output                                                                                                               |
| autoOrient | boolean | no       | `false` | Rotate/flip upright using the image's EXIF orientation before resizing                                                                                                                     |

**Returns:** array of strings - full paths to the resized output files, in `outputs` order

**Throws**

- `ImageMagick.InputValidationException` - `path` does not exist, `outputs` is empty, two outputs share a `resizeDir`, or an output entry is missing `resizeDir`, is missing both `width` and `height`, or has a `width`/`height` less than 1
- `ImageMagick.ResizeException` - ImageMagick failed to produce one of the resized outputs

**Example**

```cfc
var resizedPaths = imageService.resize(
    path    = '/tmp/uploads/photo.jpg',
    outputs = [
        {resizeDir: '/var/www/images/small', width: 100},
        {resizeDir: '/var/www/images/medium', width: 600},
        {resizeDir: '/var/www/images/banner', width: 1200, height: 400}
    ]
);
// resizedPaths = [
//     '/var/www/images/small/photo.jpg',
//     '/var/www/images/medium/photo.jpg',
//     '/var/www/images/banner/photo.jpg'
// ]
```

---

## validateUpload(formField, outputs, extensions, strip, autoOrient, maxPixels, maxFileSize, quality, resize)

Handles an entire image upload flow in one call from within a handler:

1. Uploads the file from `formField` into its own UUID-named temp directory and checks its extension against `extensions` and its size against `maxFileSize`
2. Renames it to a UUID filename, so the client's filename never reaches ImageMagick
3. Reads its header to confirm it's a genuinely valid image whose content matches its extension (not a spoofed extension), and that it is within `maxPixels`
4. Converts its first frame to every requested output type/directory in a single decode at `quality`, shrinking it to fit `resize` the same way as [`convert()`](#convertpath-outputpath-quality-resize-strip-autoorient), using a newly generated UUID as the filename

Only the first frame of an animated or multi-image upload is kept - the same frame `maxPixels` is checked against - so every output is a single image. The temp directories are always removed. If any output fails to convert, no output is written.

Set `quality` and `resize` to the final size you need rather than running `convert()` on an output afterwards - each lossy save (ex: JPEG, WebP) loses detail again, and a second pass decodes the image a second time.

**Arguments**

| Name       | Type    | Required | Default                    | Description                                                                                                                                                             |
| ---------- | ------- | -------- | -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| formField  | string  | yes      | -                          | The form field name the image was uploaded under                                                                                                                        |
| outputs    | array   | yes      | -                          | Array of structs (1-10), each `{uploadDir: string, type: string}` - `type` is the output extension (e.g. `webp`, `jpg`) and must be a supported extension. Each `uploadDir`/`type` pair must be unique |
| extensions | string  | no       | `'png,jpg,jpeg,webp,heic'` | Comma-delimited list of allowed source file extensions, each a supported extension. Whitespace and case are ignored                                                    |
| strip      | boolean | no       | `true`                     | Whether to strip metadata (EXIF, ICC profiles, etc) from each converted output. Set `false` to preserve EXIF/GPS/ICC data                                               |
| autoOrient | boolean | no       | `false`                    | Rotate/flip each output upright using the upload's EXIF orientation tag (recommended for phone camera uploads)                                                          |
| maxPixels  | numeric | no       | `100000000`                | Max width x height of the upload in pixels (100 megapixels by default). Checked from the header before the image is decoded                                            |
| maxFileSize | numeric | no      | `26214400`                 | Max size of the uploaded file in bytes (25MB by default)                                                                                                                |
| quality    | numeric | no       | `50`                       | 1-100 quality of each output                                                                                                                                            |
| resize     | numeric | no       | `1200`                     | Max width/height in pixels to shrink each output to - uploads already smaller are left at their original dimensions                                                    |

**Returns:** string - the converted files' shared UUID filename, without extension. Combine with each output's `uploadDir`/`type` to get the full path.

**Throws**

- `ImageMagick.InputValidationException` - `formField` is empty, `outputs` is empty, an output entry is missing `uploadDir` or `type`, two outputs share an `uploadDir` and `type`, an entry in `extensions` or an output `type` is not supported, `maxPixels`/`maxFileSize` is not a positive number, `resize` is less than 1, or `quality` is not between 1 and 100
- `ImageMagick.UploadValidationException` - no file was uploaded, the upload's extension is not in `extensions`, it exceeds `maxFileSize`, the upload is not a valid image, its content does not match its extension, it exceeds `maxPixels`, or an output failed to convert

**Example**

```cfc
// in a handler action, after a multipart form POST with a "file" field
function uploadPhoto(event, rc, prc) {
    var fileName = imageService.validateUpload(
        formField  = 'file',
        outputs    = [
            {uploadDir: '/var/www/images/original', type: 'jpg'},
            {uploadDir: '/var/www/images/webp', type: 'webp'}
        ],
        extensions = 'png,jpg,jpeg,heic',
        autoOrient = true
    );

    // fileName = "3f2a9c1e4b7d4a6c9e1f2a3b4c5d6e7f"
    // -> /var/www/images/original/3f2a9c1e4b7d4a6c9e1f2a3b4c5d6e7f.jpg
    // -> /var/www/images/webp/3f2a9c1e4b7d4a6c9e1f2a3b4c5d6e7f.webp
}

// save a smaller, final-size webp in the same pass instead of re-converting it afterwards
function uploadReceipt(event, rc, prc) {
    var fileName = imageService.validateUpload(
        formField  = 'file',
        outputs    = [{uploadDir: '/var/www/images/receipts', type: 'webp'}],
        autoOrient = true,
        quality    = 50,
        resize     = 750
    );
}

// preserve EXIF/GPS/ICC metadata on the converted outputs instead of stripping it
function uploadPhotoWithMetadata(event, rc, prc) {
    var fileName = imageService.validateUpload(
        formField  = 'file',
        outputs    = [{uploadDir: '/var/www/images/original', type: 'jpg'}],
        strip      = false,
        autoOrient = true
    );
}
```
