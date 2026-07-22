# Image Service Functions

Reference for every public function on the `Helpers@ImageMagick` service (`models/services/image.cfc`). Inject it with:

```cfc
property name="imageService" inject="Helpers@ImageMagick";
```

All functions validate their arguments before doing any work and throw `ImageMagick.InputValidationException` if a constraint is violated (missing required argument, path doesn't exist, non-positive number, etc). See each function below for the additional, function-specific exceptions it can throw.

## Table of Contents

- [verifyImageMagick()](#verifyimagemagick)
- [validIdentify(path)](#valididentifypath)
- [getDimensions(path)](#getdimensionspath)
- [convert(path, outputPath, quality, resize)](#convertpath-outputpath-quality-resize)
- [crop(path, outputPath, width, height)](#croppath-outputpath-width-height)
- [autoOrient(path, outputPath)](#autoorientpath-outputpath)
- [resize(path, outputs)](#resizepath-outputs)
- [validateUpload(formField, outputs, extensions)](#validateuploadformfield-outputs-extensions)

---

## verifyImageMagick()

Checks that the configured `imageMagickPath` points to a working ImageMagick install by running `identify -version` and confirming it returns output. Useful as a startup/health check.

**Arguments:** none

**Returns:** nothing (`void`)

**Throws**

- `ImageMagick.VerificationException` - ImageMagick could not be reached, or did not return version information

**Example**

```cfc
imageService.verifyImageMagick();
```

---

## validIdentify(path)

Runs ImageMagick `identify` against `path` to confirm the file is a real, readable image (not just a file with an image-like extension).

**Arguments**

| Name | Type   | Required | Description                     |
| ---- | ------ | -------- | ------------------------------- |
| path | string | yes      | Full path to the image to check |

**Returns:** nothing (`void`)

**Throws**

- `ImageMagick.InputValidationException` - `path` is empty or does not exist
- `ImageMagick.IdentifyException` - ImageMagick reports `path` is not a valid image

**Example**

```cfc
imageService.validIdentify('/tmp/uploads/photo.jpg');
```

---

## getDimensions(path)

Reads the pixel width/height of an image's first frame.

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

## convert(path, outputPath, quality, resize)

Strips metadata, adjusts quality, and shrink-to-fits the source image, writing the result to `outputPath`. The output format is determined by `outputPath`'s extension. Only shrinks the image if it exceeds `resize` - images already smaller than that bound are left at their original dimensions.

**Arguments**

| Name       | Type    | Required | Default | Description                                   |
| ---------- | ------- | -------- | ------- | --------------------------------------------- |
| path       | string  | yes      | -       | Full path to source image                     |
| outputPath | string  | yes      | -       | Full path to output file, including extension |
| quality    | numeric | no       | `50`    | 0-100 output quality                          |
| resize     | numeric | no       | `1200`  | Max width/height in pixels to shrink to       |

**Returns:** nothing (`void`)

**Throws**

- `ImageMagick.InputValidationException` - `path` does not exist, `outputPath` is empty, `quality` is not between 0 and 100, or `resize` is not a positive number
- `ImageMagick.ConversionException` - ImageMagick failed to produce the converted output

**Example**

```cfc
imageService.convert(
    path       = '/tmp/uploads/photo.jpg',
    outputPath = '/var/www/images/photo.webp',
    quality    = 75,
    resize     = 1600
);
```

---

## crop(path, outputPath, width, height)

Crops the source image to exact `width`x`height` dimensions: scales the image to fully cover the target box (preserving aspect ratio) then crops the overflow from the center. Unlike [`resize()`](#resizepath-outputs)'s forced-dimensions mode, this never distorts the image.

**Arguments**

| Name       | Type    | Required | Description                                   |
| ---------- | ------- | -------- | --------------------------------------------- |
| path       | string  | yes      | Full path to source image                     |
| outputPath | string  | yes      | Full path to output file, including extension |
| width      | numeric | yes      | Target width in pixels                        |
| height     | numeric | yes      | Target height in pixels                       |

**Returns:** nothing (`void`)

**Throws**

- `ImageMagick.InputValidationException` - `path` does not exist, `outputPath` is empty, or `width`/`height` is not a positive number
- `ImageMagick.CropException` - ImageMagick failed to produce the cropped output

**Example**

```cfc
imageService.crop(
    path       = '/var/www/images/photo.jpg',
    outputPath = '/var/www/images/photo_thumb.jpg',
    width      = 300,
    height     = 300
);
```

---

## autoOrient(path, outputPath)

Physically rotates/flips the image according to its EXIF orientation tag and removes that tag, writing the result to `outputPath`. Photos uploaded directly from phone cameras are frequently stored sideways/upside-down with only an EXIF flag marking the correct orientation - most browsers and image libraries ignore that flag, so this bakes the correct orientation into the pixels.

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

## resize(path, outputs)

Resizes the source image to one or more output sizes in a single call. If both `width` and `height` are given for an output, the image is forced to those exact dimensions (aspect ratio ignored). If only one is given, the image is scaled to that dimension with aspect ratio preserved. Each output's destination filename matches the source filename, placed in that output's `resizeDir`. If a resized file already exists at the destination, it is intentionally overwritten. If any output fails, all outputs already resized in this call are deleted before the exception is thrown.

**Arguments**

| Name    | Type   | Required | Description                                                                                                                                                           |
| ------- | ------ | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| path    | string | yes      | Full path to source image                                                                                                                                             |
| outputs | array  | yes      | Array of structs (1-10), each `{resizeDir: string, width: numeric, height: numeric}`. `resizeDir` is required; at least one of `width`/`height` is required per entry |

**Returns:** array of strings - full paths to the successfully resized output files, in `outputs` order

**Throws**

- `ImageMagick.InputValidationException` - `path` does not exist, `outputs` is empty, or an output entry is missing `resizeDir`, is missing both `width` and `height`, or has a non-positive `width`/`height`
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

## validateUpload(formField, outputs, extensions)

Handles an entire image upload flow in one call from within a handler: uploads the file from `formField` to a temp directory, verifies it's a genuinely valid image (not just a spoofed extension), checks its extension against `extensions`, then converts it to each requested output type/directory via [`convert()`](#convertpath-outputpath-quality-resize) using a newly generated UUID as the filename. The temp upload is always cleaned up. If any output fails to convert, all outputs already converted in this call are deleted before the exception is thrown.

**Arguments**

| Name       | Type   | Required | Default                    | Description                                                                                                             |
| ---------- | ------ | -------- | -------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| formField  | string | yes      | -                          | The form field name the image was uploaded under                                                                        |
| outputs    | array  | yes      | -                          | Array of structs (1-10), each `{uploadDir: string, type: string}` - `type` is the output extension (e.g. `webp`, `jpg`) |
| extensions | string | no       | `'png,jpg,jpeg,webp,heic'` | Comma-delimited list of allowed source file extensions                                                                  |

**Returns:** string - the converted files' shared UUID filename, without extension. Combine with each output's `uploadDir`/`type` to get the full path.

**Throws**

- `ImageMagick.InputValidationException` - `formField` is empty, `outputs` is empty, or an output entry is missing `uploadDir` or `type`
- `ImageMagick.UploadValidationException` - no file was uploaded, the upload is not a valid image, the upload's extension is not in `extensions`, or an output failed to convert

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
        extensions = 'png,jpg,jpeg'
    );

    // fileName = "3f2a9c1e4b7d4a6c9e1f2a3b4c5d6e7f"
    // -> /var/www/images/original/3f2a9c1e4b7d4a6c9e1f2a3b4c5d6e7f.jpg
    // -> /var/www/images/webp/3f2a9c1e4b7d4a6c9e1f2a3b4c5d6e7f.webp
}
```
