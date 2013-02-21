#import <Kiwi/Kiwi.h>
#import <OCMock-iPhone/OCMock.h>
#import "PLImageCache.h"
#import "UIImage+RandomImage.h"

@interface PLImageCache ()

- (id)initWithCache:(NSCache *)cache fileManager:(NSFileManager *)manager;
- (NSURL *)imageCacheDirectory;

@end

SPEC_BEGIN(PLImageCacheSpecs)

describe(@"PLImageCache", ^{
    describe(@"setting a image", ^{
        __block PLImageCache * imageCache;
        __block id fileManagerStub;
        __block id memoryCacheStub;
        NSString * const key = @"abcde";

        beforeEach(^{
            fileManagerStub = [OCMockObject partialMockForObject:[NSFileManager defaultManager]];
            memoryCacheStub = [OCMockObject niceMockForClass:[NSCache class]];
            imageCache = [[PLImageCache alloc] initWithCache:memoryCacheStub
                                                 fileManager:fileManagerStub];
        });

        context(@"when non-nil", ^{
            __block UIImage* imageMock;
            
            beforeAll(^{
                imageMock = [UIImage randomImage];
            });
            
            it(@"should store it in the file cache", ^{
                [[fileManagerStub expect] createFileAtPath:[OCMArg any]
                                                  contents:[OCMArg any]
                                                attributes:[OCMArg any]];
                
                [imageCache set:imageMock
                         forKey:key];
                
                [fileManagerStub verify];
            });
            
            it(@"should store it in the memory cache", ^{
                [[memoryCacheStub expect] setObject:imageMock
                                             forKey:key];
                
                [imageCache set:imageMock
                         forKey:key];
                
                [memoryCacheStub verify];
            });
        });

        context(@"when nil", ^{
            it(@"should remove it from the file cache", ^{
                [[fileManagerStub expect] removeItemAtPath:[OCMArg checkWithBlock:^BOOL(id value){
                    return [value isKindOfClass:[NSString class]] && [value rangeOfString:[[imageCache imageCacheDirectory] path]].location == 0;
                }]
                                                     error:(NSError __autoreleasing **)[OCMArg anyPointer]];
                
                [imageCache set:nil
                         forKey:key];
                
                [fileManagerStub verify];
            });
            
            it(@"should remove it from the memory cache", ^{
                [[memoryCacheStub expect] removeObjectForKey:key];
                
                [imageCache set:nil
                         forKey:key];
                
                [memoryCacheStub verify];
            });
        });
    });
    
    describe(@"removing a image", ^{
        __block PLImageCache * imageCache;
        __block id fileManagerStub;
        __block id memoryCacheStub;
        NSString * const key = @"abcde";
        
        beforeEach(^{
            fileManagerStub = [OCMockObject partialMockForObject:[NSFileManager defaultManager]];
            memoryCacheStub = [OCMockObject niceMockForClass:[NSCache class]];
            imageCache = [[PLImageCache alloc] initWithCache:memoryCacheStub
                                                 fileManager:fileManagerStub];
        });
        
        it(@"should remove it from the file cache", ^{
            [[fileManagerStub expect] removeItemAtPath:[OCMArg checkWithBlock:^BOOL(id value){
                return [value isKindOfClass:[NSString class]] && [value rangeOfString:[[imageCache imageCacheDirectory] path]].location == 0;
            }]
                                                 error:(NSError __autoreleasing **)[OCMArg anyPointer]];
            
            [imageCache removeImageWithKey:key];
            
            [fileManagerStub verify];
        });
        
        it(@"should remove it from the memory cache", ^{
            [[memoryCacheStub expect] removeObjectForKey:key];
            
            [imageCache removeImageWithKey:key];
            
            [memoryCacheStub verify];
        });
    });
    
    describe(@"clearing", ^{
        __block PLImageCache * imageCache;
        __block id fileManagerStub;
        __block id memoryCacheStub;

        
        beforeEach(^{
            fileManagerStub = [OCMockObject partialMockForObject:[NSFileManager defaultManager]];
            memoryCacheStub = [OCMockObject niceMockForClass:[NSCache class]];
            imageCache = [[PLImageCache alloc] initWithCache:memoryCacheStub
                                                 fileManager:fileManagerStub]; 
        });
        
        it(@"should work for the file cache", ^{
            [[fileManagerStub expect] removeItemAtPath:[[imageCache imageCacheDirectory] path]
                                                 error:(NSError __autoreleasing **)[OCMArg anyPointer]];
            
            [imageCache clearFileCache];
            
            [fileManagerStub verify];
        });
        
        it(@"should work for the memory cache", ^{
            [[memoryCacheStub expect] removeAllObjects];

            [imageCache clearMemoryCache];

            [memoryCacheStub verify];
        });
    });
});

SPEC_END