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

            describe(@"should not take longer then 10ms for the call to imageForIdentifier:placeholder:callback:", ^{
                __block UIImage *placeholderImage;
                NSUInteger const numberOfCycles = 10;
                NSTimeInterval const timeout = 0.01;

                beforeAll(^{
                    placeholderImage = [UIImage randomImageWithSize:CGSizeMake(16, 16)];
                });

                it(@"in quick flow scenario", ^{
                    for(int i = 0; i < numberOfCycles; ++i){
                        NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
                        [imageManager imageForIdentifier:identifier
                                             placeholder:placeholderImage
                                                callback:nil];
                        [[theValue([NSDate timeIntervalSinceReferenceDate] - startTime) should] beLessThanOrEqualTo:theValue(timeout)];
                    }
                });

                it(@"in slow path (file) scenario", ^{
                    [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) withBlock:^id(NSArray *params) {
                        if ([[params objectAtIndex:1] boolValue] == YES) {
                            return nil;
                        } else {
                            return quickImage;
                        }
                    }];
                    for(int i = 0; i < numberOfCycles; ++i){
                        NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
                        [imageManager imageForIdentifier:identifier
                                             placeholder:placeholderImage
                                                callback:nil];
                        [[theValue([NSDate timeIntervalSinceReferenceDate] - startTime) should] beLessThanOrEqualTo:theValue(timeout)];
                    }
                });

                it(@"in slow path (network) scenario", ^{
                    [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:nil]; //force slow (network) path
                    [providerMock stub:@selector(downloadImageWithIdentifier:error:) andReturn:quickImage];

                    for(int i = 0; i < numberOfCycles; ++i){
                        NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
                        [imageManager imageForIdentifier:identifier
                                             placeholder:placeholderImage
                                                callback:nil];
                        [[theValue([NSDate timeIntervalSinceReferenceDate] - startTime) should] beLessThanOrEqualTo:theValue(timeout)];
                    }
                });
            });

            describe(@"should return a token", ^{

                it(@"that is not nil", ^{
                    PLImageManagerRequestToken *token = [imageManager imageForIdentifier:identifier
                                                                             placeholder:nil
                                                                                callback:nil];
                    [[token shouldNot] beNil];
                });

                describe(@"that properly reports it's isReady state", ^{
                    __block NSCondition *checkerLock;
                    __block NSCondition *downloadLock;

                    beforeEach(^{
                        checkerLock = [NSCondition new];
                        downloadLock = [NSCondition new];
                    });

                    afterEach(^{
                        [downloadLock lock];
                        [downloadLock broadcast];
                        [downloadLock unlock];
                        [checkerLock lock];
                        [checkerLock broadcast];
                        [checkerLock unlock];
                    });

                    it(@"in quick flow scenario", ^{
                        PLImageManagerRequestToken *token = [imageManager imageForIdentifier:identifier
                                                                                 placeholder:nil
                                                                                    callback:nil];
                        [[theValue(token.isReady) should] beTrue];
                    });

                    it(@"in slow path (file) scenario", ^{
                        [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) withBlock:^id(NSArray *params) {
                            if ([[params objectAtIndex:1] boolValue] == YES){
                                return nil;
                            } else {
                                [downloadLock lock];
                                [checkerLock lock];
                                NSLog(@"will signal checker");
                                [checkerLock signal];
                                [checkerLock unlock];
                                NSLog(@"start hang on download");
                                [downloadLock wait];
                                NSLog(@"stop hang on download");
                                [downloadLock unlock];
                                return quickImage;
                            }
                        }];

                        [checkerLock lock];
                        PLImageManagerRequestToken *token = [imageManager imageForIdentifier:identifier
                                                                                 placeholder:nil
                                                                                    callback:nil];

                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                        [[theValue(token.isReady) should] beFalse];

                        [downloadLock lock];
                        [downloadLock signal];
                        [downloadLock unlock];

                        [checkerLock unlock];

                        for(int i = 9; i >= 0; --i){
                            if(token.isReady){
                                break;
                            }
                            if (i == 0){
                                [[theValue(token.isReady) should] beTrue];
                            } else {
                                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
                            }
                        }
                    });

                    it(@"in slow path (network) scenario", ^{
                        [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:nil]; //force slow (network) path
                        [providerMock stub:@selector(downloadImageWithIdentifier:error:) withBlock:^id(NSArray *params) {
                            [downloadLock lock];
                            [checkerLock lock];
                            [checkerLock signal];
                            [checkerLock unlock];
                            [downloadLock wait];
                            [downloadLock unlock];
                            return quickImage;
                        }];

                        [checkerLock lock];
                        PLImageManagerRequestToken *token = [imageManager imageForIdentifier:identifier
                                                                                 placeholder:nil
                                                                                    callback:nil];

                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]]) should] equal:theValue(YES)];//should be signaled
                        [[theValue(token.isReady) should] beFalse];

                        [downloadLock lock];
                        [downloadLock signal];
                        [downloadLock unlock];

                        [checkerLock unlock];

                        for(int i = 9; i >= 0; --i){
                            if(token.isReady){
                                break;
                            }
                            if (i == 0){
                                [[theValue(token.isReady) should] beTrue];
                            } else {
                                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
                            }
                        }
                    });
                });
            });
        });

        describe(@"multiple images simultanously", ^{
            it(@"should download all of them(on not more then maxConcurrentDownloadsCount threads)", ^{
                //configuration
                __block NSString *identifierTemplate = @"example_%d";
                NSUInteger const maxDownloadCount = 5;
                __block NSCondition *downloadLock;
                __block NSCondition *checkerLock;
                __block NSInteger runningDownloads = 0;
                __block NSInteger downloadsLeft = 10;

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

                //test
                [checkerLock lock];
                for (int i = downloadsLeft; i > 0; --i) {
                    [imageManager imageForIdentifier:[NSString stringWithFormat:identifierTemplate, i]
                                         placeholder:nil callback:nil];
                }
                [checkerLock unlock];

                while (downloadsLeft > 0) {
                    [checkerLock lock];
                    [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]]) should] equal:theValue(YES)];//should be signaled
                    [[theValue(runningDownloads) should] beLessThanOrEqualTo:theValue(maxDownloadCount)];
                    [checkerLock unlock];
                }

                //cleanup
                [downloadLock lock];
                [downloadLock broadcast];
                [downloadLock unlock];
                [checkerLock lock];
                [checkerLock broadcast];
                [checkerLock unlock];
            });

            describe(@"should download in", ^{
                __block NSString *identifierTemplate = @"example_%d";
                NSUInteger const maxDownloadCount = 1;
                __block NSCondition *checkerLock;
                __block NSCondition *downloadLock;
                __block NSString *lastDownloaded;

                beforeEach(^{
                    [providerMock stub:@selector(maxConcurrentDownloadsCount) andReturn:theValue(maxDownloadCount)];
                    checkerLock = [NSCondition new];
                    downloadLock = [NSCondition new];
                    [providerMock stub:@selector(downloadImageWithIdentifier:error:) withBlock:^id(NSArray *params) {
                        lastDownloaded = [params objectAtIndex:0];
                        [downloadLock lock];
                        [checkerLock lock];
                        [checkerLock signal];
                        [checkerLock unlock];
                        [downloadLock wait];
                        [downloadLock unlock];
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

                it(@"FIFO order", ^{
                    [checkerLock lock];
                    [imageManager imageForIdentifier:@"0"
                                         placeholder:nil callback:nil];
                    [imageManager imageForIdentifier:@"1"
                                         placeholder:nil callback:nil];
                    [imageManager imageForIdentifier:@"2"
                                         placeholder:nil callback:nil];

                    [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                    [[lastDownloaded should] equal:@"0"];

                    [downloadLock lock];
                    [downloadLock signal];
                    [downloadLock unlock];

                    [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                    [[lastDownloaded should] equal:@"1"];

                    [downloadLock lock];
                    [downloadLock signal];
                    [downloadLock unlock];

                    [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                    [[lastDownloaded should] equal:@"2"];

                    [downloadLock lock];
                    [downloadLock signal];
                    [downloadLock unlock];

                    [checkerLock unlock];
                });

                //TODO: write a "weak" test for deferCurrentDownloads
                it(@"FIFO order taking calls to 'deferCurrentDownloads' into account", ^{
                    [checkerLock lock];
                    [downloadLock lock];
                    [imageManager imageForIdentifier:@"a0"
                                         placeholder:nil callback:nil];
                    [imageManager imageForIdentifier:@"a1"
                                         placeholder:nil callback:nil];
                    [imageManager imageForIdentifier:@"a2"
                                         placeholder:nil callback:nil];
                    [imageManager imageForIdentifier:@"a3"
                                         placeholder:nil callback:nil];
                    [imageManager imageForIdentifier:@"a4"
                                         placeholder:nil callback:nil];
                    [downloadLock unlock];

                    [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                    [[lastDownloaded should] equal:@"a0"];

                    [imageManager deferCurrentDownloads];

                    [imageManager imageForIdentifier:@"b0"
                                         placeholder:nil callback:nil];

                    [checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

                    [downloadLock lock];
                    [downloadLock signal];
                    [downloadLock unlock];

                    [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                    [[lastDownloaded should] equal:@"b0"];

                    [downloadLock lock];
                    [downloadLock signal];
                    [downloadLock unlock];

                    [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                    [[lastDownloaded should] equal:@"a1"];

                    [downloadLock lock];
                    [downloadLock signal];
                    [downloadLock unlock];

                    [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                    [[lastDownloaded should] equal:@"a2"];

                    [downloadLock lock];
                    [downloadLock signal];
                    [downloadLock unlock];

                    [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                    [[lastDownloaded should] equal:@"a3"];

                    [downloadLock lock];
                    [downloadLock signal];
                    [downloadLock unlock];

                    [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                    [[lastDownloaded should] equal:@"a4"];

                    [downloadLock lock];
                    [downloadLock signal];
                    [downloadLock unlock];

                    [checkerLock unlock];
                });

                describe(@"FIFO order taking cancels into account", ^{
                    it(@"for non-repeating requests", ^{
                        [checkerLock lock];
                        [downloadLock lock];
                        PLImageManagerRequestToken * token = nil;
                        [imageManager imageForIdentifier:@"a0"
                                             placeholder:nil callback:nil];
                        token = [imageManager imageForIdentifier:@"a1"
                                                     placeholder:nil callback:nil];
                        [imageManager imageForIdentifier:@"a2"
                                             placeholder:nil callback:nil];
                        [downloadLock unlock];

                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                        [[lastDownloaded should] equal:@"a0"];

                        [token cancel];

                        [downloadLock lock];
                        [downloadLock signal];
                        [downloadLock unlock];

                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                        [[lastDownloaded should] equal:@"a2"];

                        [downloadLock lock];
                        [downloadLock signal];
                        [downloadLock unlock];

                        lastDownloaded = nil;
                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(NO)];//should time out
                        [[lastDownloaded should] beNil];

                        [checkerLock unlock];
                    });

                    it(@"for repeting requests", ^{
                        [checkerLock lock];
                        [downloadLock lock];
                        PLImageManagerRequestToken * token = nil;
                        [imageManager imageForIdentifier:@"a0"
                                             placeholder:nil callback:nil];
                        token = [imageManager imageForIdentifier:@"a1"
                                                     placeholder:nil callback:nil];
                        [imageManager imageForIdentifier:@"a2"
                                             placeholder:nil callback:nil];
                        [imageManager imageForIdentifier:@"a1"
                                             placeholder:nil callback:nil];
                        [downloadLock unlock];

                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                        [[lastDownloaded should] equal:@"a0"];

                        [token cancel];

                        [downloadLock lock];
                        [downloadLock signal];
                        [downloadLock unlock];

                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                        [[lastDownloaded should] equal:@"a1"];

                        [downloadLock lock];
                        [downloadLock signal];
                        [downloadLock unlock];

                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
                        [[lastDownloaded should] equal:@"a2"];

                        [downloadLock lock];
                        [downloadLock signal];
                        [downloadLock unlock];

                        [checkerLock unlock];
                    });
                });
            });
        });
    });
});

SPEC_END