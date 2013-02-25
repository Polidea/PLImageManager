#import <Kiwi/Kiwi.h>
#import "PLImageManager.h"
#import "PLImageCache.h"
#import "UIImage+RandomImage.h"
#include <libkern/OSAtomic.h>
#import <OCMock-iPhone/OCMArg.h>

@interface PLImageManager ()

- (id)initWithProvider:(id <PLImageManagerProvider>)aProvider cache:(PLImageCache *)aCache;

@end

SPEC_BEGIN(PLImageManagerSpecs)

describe(@"PLImageManager", ^{
    __block UIImage * quickImage;

    beforeAll(^{
        quickImage = [UIImage randomImageWithSize:CGSizeMake(32, 32)];
    });

    describe(@"during creation", ^{
        __block PLImageManager * imageManager;

        it(@"should complain about missing provider", ^{
            [[theBlock(^{
                imageManager = [[PLImageManager alloc] initWithProvider:nil];
            }) should] raiseWithName:@"InvalidArgumentException"];
        });

        it(@"should ask the provider for the maxConcurrentDownloadsCount", ^{
            id provider = [KWMock nullMockForProtocol:@protocol(PLImageManagerProvider)];

            [[[provider should] receive] maxConcurrentDownloadsCount];

            imageManager = [[PLImageManager alloc] initWithProvider:provider];
        });
    });

    describe(@"requesting", ^{
        __block Class identifierClass;
        __block PLImageManager * imageManager;
        __block id providerMock;
        __block id cacheMock;

        beforeAll(^{
            identifierClass = [NSString class];
        });

        beforeEach(^{
            providerMock = [KWMock nullMockForProtocol:@protocol(PLImageManagerProvider)];
            cacheMock = [KWMock nullMockForClass:[PLImageCache class]];
            [providerMock stub:@selector(identifierClass) andReturn:theValue(identifierClass)];
            [providerMock stub:@selector(keyForIdentifier:) withBlock:^id(NSArray *params) {
                return [params objectAtIndex:0];
            }];
        });

        describe(@"a image", ^{
            __block NSString * identifier = @"example_id";

            beforeEach(^{
                [providerMock stub:@selector(keyForIdentifier:) andReturn:identifier];
                [providerMock stub:@selector(maxConcurrentDownloadsCount) andReturn:theValue(1)];
                [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:quickImage]; //force quick path
                imageManager = [[PLImageManager alloc] initWithProvider:providerMock cache:cacheMock];
            });

            describe(@"should ask the provider", ^{
                it(@"for the identifier class", ^{
                    [[[providerMock should] receive] identifierClass];

                    [imageManager imageForIdentifier:identifier placeholder:nil callback:nil];
                });

                it(@"for the identifier class and throw an exception on missmatch", ^{
                    [[theBlock(^{
                        [imageManager imageForIdentifier:[NSDate date] placeholder:nil callback:nil];
                    }) should] raiseWithName:@"InvalidArgumentException"];
                });

                it(@"for the key resulting from the identifier", ^{
                    [[[providerMock should] receive] keyForIdentifier:identifier];
                    [imageManager imageForIdentifier:identifier placeholder:nil callback:nil];
                });

                it(@"to download the image", ^{
                    NSThread * const callThread = [NSThread currentThread];

                    [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:nil]; //force slow (network) path
                    [providerMock stub:@selector(downloadImageWithIdentifier:error:)
                             withBlock:^id(NSArray *params) {
                                 [[[NSThread currentThread] shouldNot] equal:callThread];
                                 return nil;
                             }];

                    [[providerMock shouldEventuallyBeforeTimingOutAfter(1.0)] receive:@selector(downloadImageWithIdentifier:error:)];

                    [imageManager imageForIdentifier:identifier placeholder:nil callback:nil];
                });
            });

            describe(@"should ask the cache", ^{
                it(@"for images already in memory)", ^{
                    [[cacheMock should] receive:@selector(getWithKey:onlyMemoryCache:) withArguments:identifier, theValue(YES)];

                    [imageManager imageForIdentifier:identifier placeholder:nil callback:nil];
                });

                it(@"for image on the file system (not on the calling thread)", ^{
                    NSThread * const callThread = [NSThread currentThread];

                    [cacheMock stub:@selector(getWithKey:onlyMemoryCache:)
                          withBlock:^id(NSArray *params) {
                              if ([[params objectAtIndex:1] boolValue] == YES){
                                  return nil;
                              } else  {
                                  [[[NSThread currentThread] shouldNot] equal:callThread];
                                  return nil;
                              }
                          }];
                    [providerMock stub:@selector(downloadImageWithIdentifier:error:) andReturn:quickImage];

                    [[cacheMock shouldEventuallyBeforeTimingOutAfter(1.0)] receive:@selector(getWithKey:onlyMemoryCache:) withArguments:identifier, theValue(NO)];

                    [imageManager imageForIdentifier:identifier placeholder:nil callback:nil];
                });
            });

            describe(@"should use the notification callback", ^{
                __block UIImage * placeholderImage;

                beforeAll(^{
                    placeholderImage = [UIImage randomImageWithSize:CGSizeMake(16, 16)];
                });

                it(@"in quick flow scenario", ^{
                    __block BOOL wasCalled = NO;
                    [imageManager imageForIdentifier:identifier
                                         placeholder:placeholderImage
                                            callback:^(UIImage *image, BOOL isPlaceholder) {
                                                wasCalled = YES;
                                                [[image should] equal:quickImage];
                                                [[theValue(isPlaceholder) should] equal:theValue(NO)];
                                            }];

                    //should be called synchronously => at this point already executed
                    [[theValue(wasCalled) should] equal:theValue(YES)];
                });

                it(@"in slow path (file) scenario", ^{
                    [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) withBlock:^id(NSArray *params) {
                        if ([[params objectAtIndex:1] boolValue] == YES){
                            return nil;
                        } else {
                            return quickImage;
                        }
                    }];
//                    [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:nil withArguments:identifier, @(YES), nil];
//                    [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:quickImage withArguments:identifier, @(NO), nil];
                    __block NSUInteger numberOfCalls = 0;
                    __block UIImage * catchedImage;
                    __block BOOL catchedIsPlaceholder;

                    [imageManager imageForIdentifier:identifier
                                         placeholder:placeholderImage
                                            callback:^(UIImage *image, BOOL isPlaceholder) {
                                                ++numberOfCalls;
                                                if (numberOfCalls == 1){
                                                    [[image should] equal:placeholderImage];
                                                    [[theValue(isPlaceholder) shouldNot] equal:theValue(NO)];
                                                } else {
                                                    catchedImage = image;
                                                    catchedIsPlaceholder = isPlaceholder;
                                                }
                                            }];

                    [[theValue(numberOfCalls) should] equal:theValue(1)]; //placeholder invocation

                    [[expectFutureValue(catchedImage) shouldEventuallyBeforeTimingOutAfter(2.0)] equal:quickImage];
                    [[expectFutureValue(theValue(catchedIsPlaceholder)) shouldEventuallyBeforeTimingOutAfter(2.0)] equal:theValue(NO)];
                });

                it(@"in slow path (network) scenario", ^{
                    [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:nil]; //force slow (network) path
                    [providerMock stub:@selector(downloadImageWithIdentifier:error:) andReturn:quickImage];
                    __block NSUInteger numberOfCalls = 0;
                    __block UIImage * catchedImage;
                    __block BOOL catchedIsPlaceholder;

                    [imageManager imageForIdentifier:identifier
                                         placeholder:placeholderImage
                                            callback:^(UIImage *image, BOOL isPlaceholder) {
                                                ++numberOfCalls;
                                                if (numberOfCalls == 1){
                                                    [[image should] equal:placeholderImage];
                                                    [[theValue(isPlaceholder) should] equal:theValue(YES)];
                                                } else {
                                                    catchedImage = image;
                                                    catchedIsPlaceholder = isPlaceholder;
                                                }
                                            }];

                    [[theValue(numberOfCalls) should] equal:theValue(1)]; //placeholder invocation

                    [[expectFutureValue(catchedImage) shouldEventuallyBeforeTimingOutAfter(2.0)] equal:quickImage];
                    [[expectFutureValue(theValue(catchedIsPlaceholder)) shouldEventuallyBeforeTimingOutAfter(2.0)] equal:theValue(NO)];
                });
            });
        });

        describe(@"multiple images simultanously", ^{
            __block NSString * identifierTemplate = @"example_%d";
            NSUInteger const maxDownloadCount = 5;
            __block NSCondition *downloadLock;
            __block NSCondition *checkerLock;
            __block NSInteger runningDownloads;
            __block NSInteger downloadsLeft;

            beforeEach(^{
                [providerMock stub:@selector(maxConcurrentDownloadsCount) andReturn:theValue(maxDownloadCount)];
                downloadLock = [NSCondition new];
                checkerLock = [NSCondition new];
                [providerMock stub:@selector(downloadImageWithIdentifier:error:) withBlock:^id(NSArray *params) {
                    OSAtomicIncrement32(&runningDownloads);
                    //notify checker
                    [checkerLock lock];
                    [checkerLock signal];
                    [checkerLock unlock];
                    //block yourself
                    [downloadLock lock];
                    [downloadLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                    [downloadLock unlock];

                    OSAtomicDecrement32(&runningDownloads);
                    OSAtomicDecrement32(&downloadsLeft);

                    //notify checker once more
                    [checkerLock lock];
                    [checkerLock signal];
                    [checkerLock unlock];

                    return nil;
                }];
                imageManager = [[PLImageManager alloc] initWithProvider:providerMock cache:cacheMock];
            });

            afterEach(^{
                [downloadLock lock];
                [downloadLock broadcast];
                [downloadLock unlock];
                [checkerLock lock];
                [checkerLock broadcast];
                [checkerLock unlock];
            });

            it(@"should download all of them(on not more then maxConcurrentDownloadsCount threads)", ^{
                downloadsLeft = 10;
                [checkerLock lock];
                for (int i = downloadsLeft; i>0; --i){
                    [imageManager imageForIdentifier:[NSString stringWithFormat:identifierTemplate, i]
                                         placeholder:nil
                                            callback:nil];
                }
                [checkerLock unlock];

                while (downloadsLeft > 0){
                    [checkerLock lock];
                    [[theValue(runningDownloads) should] beLessThanOrEqualTo:theValue(maxDownloadCount)];
                    [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]]) should] equal:theValue(YES)];//should be signaled
                    [checkerLock unlock];
                }
            });
        });
    });
});

SPEC_END