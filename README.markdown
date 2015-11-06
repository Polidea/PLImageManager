# PLImageManager

---

This library is deprecated in favor of [PLXImageManager](https://github.com/Polidea/PLXImageManager)

---

Image manager/downloader for iOS

## Installation

* Add the files in PLImageManager/Sources to your project
* If your project doesn't use ARC, enable it for PLImageManager files (-fobjc-arc flag)
* iOS5+ is required for full ARC functionality

## Usage

### Creation

```objective-c
PLURLImageProvider * provider = [PLURLImageProvider new];
PLImageManager * manager = [[PLImageManager alloc] initWithProvider:provider];
```

The *provider* is responsible for retrieving a image if it is not available in cache. The standard PLURLImageProvider is provided as convenience. It takes a URL and simply downloads up to 5 images at once. By implementing the *PLImageManagerProvider* protocol yourself, you can adapt the manager to fit your needs.

### Requesting images

```objective-c
[manager imageForIdentifier:@”http://placehold.it/350/00aa00/ffffff”
                placeholder:[UIImage imageNamed:@”placeholder”
	               callback:^(UIImage *image, BOOL isPlaceholder) {
 	//consume the image here
}];
```

### Example

A example application is provided,

## Further reading

You can read more about the internal workings of PLImageManager [here](http://www.polidea.com/en/Blog,141,Implementing_a_high_performance_image_manager_for_iOS).

---

Copyright (c) 2013 Polidea. This software is licensed under the BSD License.
