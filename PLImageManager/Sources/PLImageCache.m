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

#import "PLImageCache.h"
#import "NSString+SHA1.h"

@interface PLImageCache ()

- (NSString *)filePathForKey:(NSString *)key;
- (void)validateKey:(NSString *)key;
- (NSURL *)imageCacheDirectory;

@end

@implementation PLImageCache {
@private
    NSCache *memoryCache;
}

- (id)init {
    self = [super init];
    if (self) {
        memoryCache = [[NSCache alloc] init];
        memoryCache.name = @"PLImageCache";
    }

    return self;
}

- (UIImage *)getWithKey:(NSString *)key onlyMemoryCache:(BOOL)onlyMemory {
    [self validateKey:key];

    NSString * filePath = [self filePathForKey:key];

    UIImage * image = [memoryCache objectForKey:key];
    if (image == nil && !onlyMemory){
        image = [UIImage imageWithContentsOfFile:filePath];
        if (image != nil) {
            [memoryCache setObject:image forKey:key];
        }
    }

    return image;
}

- (void)set:(UIImage *)image forKey:(NSString *)key {
    [self validateKey:key];

    NSString * filePath = [self filePathForKey:key];

    if (image == nil) {
        [memoryCache removeObjectForKey:key];
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];
    } else {
        [memoryCache setObject:image forKey:key];
        [[NSFileManager defaultManager] createFileAtPath:filePath contents:UIImagePNGRepresentation(image) attributes:nil];
    }
}

- (void)removeImageWithKey:(NSString *)key {
    [self validateKey:key];

    NSString * filePath = [self filePathForKey:key];
    [memoryCache removeObjectForKey:key];
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];
}

- (void)clearMemoryCache {
    [memoryCache removeAllObjects];
}

- (void)clearFileCache {
    [[NSFileManager defaultManager] removeItemAtPath:[[self imageCacheDirectory] path] error:nil];
}


-(NSString *)filePathForKey:(NSString *)key{
    return [[[self imageCacheDirectory] URLByAppendingPathComponent:[key sha1Hash]] path];
}

- (void)validateKey:(NSString *)key {
    if (key == nil) {
        @throw [NSException exceptionWithName:@"InvalidArgumentException" reason:[NSString stringWithFormat:@"The provided key \"%@\" is not valid", key] userInfo:nil];
    }
}

- (NSURL *)imageCacheDirectory {
    static NSURL *cacheDirectory;
    if (cacheDirectory == nil) {
        NSFileManager *fileMgr = [NSFileManager defaultManager];
        NSArray *urls = [fileMgr URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
        NSURL *libraryUrl = [urls count] > 0 ? [urls objectAtIndex:0] : nil;

        if (libraryUrl != nil) {
            cacheDirectory = [[libraryUrl URLByAppendingPathComponent:@"Caches"] URLByAppendingPathComponent:@"PLImageCache"];
            [fileMgr createDirectoryAtPath:[cacheDirectory path] withIntermediateDirectories:YES attributes:nil error:NULL];
        }
    }
    return cacheDirectory;
}

@end