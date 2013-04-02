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

/**
PLImageCache handles all cache related work done by PLImageManager.

It provides:

1. in memory cache based on NSCache.
2. in flash cache based on NSFileManager

The interface is synchronous. To prevent accessing the file system in the main thread the behaviour of some methods can be limited to only operate on the memory cache.

*/
@interface PLImageCache : NSObject

/**
Retrieves a image stored under key from the cache.

It tries to satisfy the request as fast as possible, queering first the memory cache, and then if necessary (and enabled) the file cache. If the image was found on the file system, it will be stored in the memory cache to speedup repeated access.

@param key the identifier for the image

@param onlyMemory if YES, only memory cache will be queried. Doing so ensures the swift return from this method (querying the file system is an order of magnitude slower). Providing NO can result in performing some IO operations, and therefor should not be called from the main thread.

@return the stored image or nil if not cached. This method will block until it's done

*/
- (UIImage *)getWithKey:(NSString *)key onlyMemoryCache:(BOOL)onlyMemory;

/**
Stores the provided image under the key.

Note: this performs a IO operation, and therefor should not be called from the main thread.

@param image the image. Providing nil will remove the image stored in the cache.

@param key key
*/
- (void)set:(UIImage *)image forKey:(NSString *)key;

/**
Same as calling [PLImageCache set:forKey:] with nil as the image.

@param key key
*/
- (void)removeImageWithKey:(NSString *)key;

/**
Clears the contents of the memory cache.
*/
-(void) clearMemoryCache;

/**
Clears the contents of the file cache. Note: this performs a IO operation, and therefor should not be called from the main thread.
*/
-(void) clearFileCache;

@end