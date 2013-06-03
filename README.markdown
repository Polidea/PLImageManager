# PLImageManager

Image manager/downloader for iOS

## Installation

* Add the files in PLImageManager/Sources to your project
* If your project doesn't use ARC, enable it for PLImageManager files (-fobjc-arc flag)
* iOS5+ is required for full ARC functionality

## Usage

### Creation
	PLURLImageProvider * provider = [PLURLImageProvider new];
	PLImageManager * manager = [[PLImageManager alloc] initWithProvider:provider];
	
The *provider* is responsible for retrieving a image if it is not available in cache. The standard PLURLImageProvider is provided as convienience. It takes a URL and simply downloads up to 5 images at once. By implementing the *PLImageManagerProvider* protocole yourself, you can adapt the manager to fit your needs.
	
### Usage
	[manager imageForIdentifier:@”http://placehold.it/350/00aa00/ffffff” 
	                placeholder:[UIImage imageNamed:@”placeholder” 
		               callback:^(UIImage *image, BOOL isPlaceholder) {
    	//consume the image here
	}];

### Example

A example application is provided, demonstrating:

* one of the ways to integrate PLImageManager into your application, by subclassing it
* canceling of image requests in a UITableView

---

Copyright (c) 2012 Polidea. This software is licensed under the BSD License.
