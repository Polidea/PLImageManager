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

#import "PLImageManager.h"
#import "PLImageCache.h"
#import "PLImageReadOperation.h"


@interface PLImageManager ()

- (id)initWithProvider:(id <PLImageManagerProvider>)aProvider cache:(PLImageCache *)aCache;

@end

@implementation PLImageManager {
@private
    NSOperationQueue *imageIOQueue;
    NSOperationQueue *imageDownloadQueue;
    PLImageCache *imageCache;
    id <PLImageManagerProvider> provider;
}

- (id)initWithProvider:(id <PLImageManagerProvider>)aProvider {
    return [self initWithProvider:aProvider cache:[PLImageCache new]];
}

//Note: this constructor is used by tests
- (id)initWithProvider:(id <PLImageManagerProvider>)aProvider cache:(PLImageCache *)aCache {
    self = [super init];
    if (self) {
        if (aProvider == nil) {
            @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:@"A valid provider is missing" userInfo:nil];
        }

        provider = aProvider;

        imageIOQueue = [NSOperationQueue new];
        imageIOQueue.name = @"plimagemanager.imageio";
        imageIOQueue.maxConcurrentOperationCount = 1;
        imageDownloadQueue = [NSOperationQueue new];
        imageDownloadQueue.name = @"plimagemanager.imagedownload";
        imageDownloadQueue.maxConcurrentOperationCount = [provider maxConcurrentDownloadsCount];

        imageCache = aCache;
    }

    return self;
}

- (void)imageForIdentifier:(id <NSObject>)identifier placeholder:(UIImage *)placeholder callback:(void (^)(UIImage *image, BOOL isPlaceholder))callback {
    Class identifierClass = [provider identifierClass];
    if (![identifier isKindOfClass:identifierClass]) {
        @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:[NSString stringWithFormat:@"The provided identifier \"%@\" is of a wrong type", identifier] userInfo:nil];
    }

    NSString *const cacheKey = [provider keyForIdentifier:identifier];

    void (^notifyBlock)(UIImage *, BOOL) = ^(UIImage *image, BOOL isPlaceholder) {
        if (callback == nil) {
            return;
        }
        if ([NSThread currentThread] == [NSThread mainThread]) {
            callback(image, isPlaceholder);
        } else {
            //note: using NSThread would be nicer, but it doesn't support blocks so stick with GCD for now
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(image, isPlaceholder);
            });
        }
    };

    //first: fast memory only cache path
    UIImage *memoryCachedImage = [imageCache getWithKey:cacheKey onlyMemoryCache:YES];
    if (memoryCachedImage != nil) {
        notifyBlock(memoryCachedImage, NO);
        return;
    } else {
        if (placeholder != nil) {
            notifyBlock(placeholder, YES);
        }
    }

    //second: file cache path
    __weak __block PLImageReadOperation *weakFileReadOperation;

    PLImageReadOperation *fileReadOperation = [[PLImageReadOperation alloc] initWithKey:cacheKey workBlock:^UIImage * {
        return [imageCache getWithKey:cacheKey onlyMemoryCache:NO];
    }];

    weakFileReadOperation = fileReadOperation;

    fileReadOperation.readyBlock = ^(UIImage *image) {
        if (image != nil) {
            notifyBlock(image, NO);
        } else {
            //finally: network path
            __block PLImageReadOperation *downloadOperation = nil;
            @synchronized (imageDownloadQueue) {
                for (PLImageReadOperation *op in imageDownloadQueue.operations) {
                    if ([op.key isEqualToString:cacheKey]) {
                        downloadOperation = op;
                        break;
                    }
                }

                if (downloadOperation == nil) {
                    downloadOperation = [[PLImageReadOperation alloc] initWithKey:cacheKey workBlock:^UIImage * {
                        NSError *error = NULL;
                        UIImage *image = [provider downloadImageWithIdentifier:identifier error:&error];

                        if (error) {
                            NSLog(@"Error downloading image: %@", error);
                        }

                        return image;
                    }];
                    downloadOperation.readyBlock = ^(UIImage *image) {
                        if (image != nil) {
                            NSBlockOperation *storeOperation = [NSBlockOperation blockOperationWithBlock:^{
                                [imageCache set:image forKey:cacheKey];
                            }];
                            storeOperation.queuePriority = NSOperationQueuePriorityHigh;
                            @synchronized (imageIOQueue) {
                                [imageIOQueue addOperation:storeOperation];
                            }
                        }
                    };
                    downloadOperation.queuePriority = weakFileReadOperation.queuePriority;
                    [imageDownloadQueue addOperation:downloadOperation];
                } else {
                    if (downloadOperation.queuePriority < weakFileReadOperation.queuePriority) {
                        downloadOperation.queuePriority = weakFileReadOperation.queuePriority;
                    }
                }
            }

            NSBlockOperation *notifyOperation = [NSBlockOperation blockOperationWithBlock:^{
                notifyBlock(downloadOperation.image, NO);
            }];
            [notifyOperation addDependency:downloadOperation];
            notifyOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
            @synchronized (imageIOQueue) {
                [imageIOQueue addOperation:notifyOperation];
            }
        }
    };
    @synchronized (imageIOQueue) {
        [imageIOQueue addOperation:fileReadOperation];
    }
}

- (void)deferCurrentDownloads {
    @synchronized (imageIOQueue) {
        [imageIOQueue setSuspended:YES];
        for (NSOperation *op in imageIOQueue.operations) {
            if ([op isKindOfClass:[PLImageReadOperation class]]) {
                op.queuePriority = NSOperationQueuePriorityLow;
            }
        }
        [imageIOQueue setSuspended:NO];
    }
    @synchronized (imageDownloadQueue) {
        [imageDownloadQueue setSuspended:YES];
        for (PLImageReadOperation *op in imageDownloadQueue.operations) {
            op.queuePriority = NSOperationQueuePriorityLow;
        }
        [imageDownloadQueue setSuspended:NO];
    }
}

- (void)clearCache {
    [imageCache clearMemoryCache];
}

@end