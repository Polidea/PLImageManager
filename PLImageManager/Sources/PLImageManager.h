/*
 Copyright (c) 2013, Antoni Kędracki, Polidea
 All rights reserved.

 mailto: akedracki@gmail.com

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the Polidea nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY ANTONI KĘDRACKI, POLIDEA ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL ANTONI KĘDRACKI, POLIDEA BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class PLImageCache;
@protocol PLImageManagerProvider;

/**
* PLImageManager is a sophisticated and extensible image manager. It covers the part of the job that is common for most use cases.
* The responsibility for the 'other' part is left to a PLImageManagerProvider (a constructor argument).
*
* It implements a asynchronous interface using a callback, with a optional 'placeholder' image argument. The callback is always called on the main thread.
*
* There are three main paths of execution:
* a) fast memory cache path: if the requested image is available in memory, it will be delivered immediately (still using the callback)
* b) file cache path: if available from flash memory, it will be loaded and delivered asynchronously.
* c) network path: in the worst case it will be downloaded, stored, and delivered asynchronously.
*
* The underlying thread schema assures that:
 * a) no more then ONE IO operation is performed at once. This is to prevent the IO from degrading the main thread performance.
 * b) downloads are performed in parallel on up to maxConcurrentDownloadsCount threads (value taken from PLImageManagerProvider).
 * c) multiple requests for the same image are handled by a single download.
*/
@interface PLImageManager : NSObject

- (id)initWithProvider:(id <PLImageManagerProvider>)provider;

/**
* Requests a image.
*
* Depending on the availability of the image the placeholder will be called:
*
* a) fast memory cache path: synchronously with the method call
* b) file cache path and network path: asynchronously when the image is available. Additionally, if a placeholder is provided, the callback will be called synchronously with it before returning from the method.
* c) in case of error the callback will be called with nil as the image parameter.
*/
- (void)imageForIdentifier:(id <NSObject>)identifier placeholder:(UIImage *)placeholder callback:(void (^)(UIImage *image, BOOL isPlaceholder))callback;

- (void)deferCurrentDownloads;

- (void)clearCache;

@end

@protocol PLImageManagerProvider <NSObject>
@required
- (NSUInteger)maxConcurrentDownloadsCount;

- (Class)identifierClass;

- (NSString *)keyForIdentifier:(id <NSObject>)identifier;

- (UIImage *)downloadImageWithIdentifier:(id <NSObject>)identifier error:(NSError **)error;

@end