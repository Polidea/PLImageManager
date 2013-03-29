#import <Kiwi/Kiwi.h>
#import "PLImageManager.h"
#import "PLImageCache.h"
#import "UIImage+RandomImage.h"
#import "PLImageManagerOpRunner.h"
#import "PLImageMangerOpRunnerFake.h"
#include <libkern/OSAtomic.h>

@interface PLImageManager ()

- (id)initWithProvider:(id <PLImageManagerProvider>)aProvider cache:(PLImageCache *)aCache ioOpRunner:(PLImageManagerOpRunner *)ioOpRunner downloadOpRunner:(PLImageManagerOpRunner *)downloadOpRunner sentinelOpRunner:(PLImageManagerOpRunner *)sentinelOpRunner;

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
        __block PLImageMangerOpRunnerFake * ioOpRunner;
        __block PLImageMangerOpRunnerFake * downloadOpRunner;
        __block PLImageMangerOpRunnerFake * sentinelOpRunner;

        __block BOOL (^drainOpRunners)(NSUInteger) = ^(NSUInteger limit){
            int i = limit;
            while(i > 0){

                NSUInteger exec = 0;
                exec += [ioOpRunner step] ? 1 : 0;
                exec += [downloadOpRunner step] ? 1 : 0;
                exec += [sentinelOpRunner step] ? 1 : 0;
                NSLog(@"exec[%d]: %d", i, exec);
                if(exec == 0){
                    return YES;
                }
                --i;
                [NSThread sleepForTimeInterval:0.001];
            };
            return NO;
        };

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

            ioOpRunner = [PLImageMangerOpRunnerFake new];
            downloadOpRunner = [PLImageMangerOpRunnerFake new];
            sentinelOpRunner = [PLImageMangerOpRunnerFake new];
        });

        describe(@"a image", ^{
            __block NSString * identifier = @"example_id";

            beforeEach(^{
                [providerMock stub:@selector(keyForIdentifier:) andReturn:identifier];
                [providerMock stub:@selector(maxConcurrentDownloadsCount) andReturn:theValue(1)];
                [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:quickImage]; //force quick path
                imageManager = [[PLImageManager alloc] initWithProvider:providerMock
                                                                  cache:cacheMock
                                                             ioOpRunner:ioOpRunner
                                                       downloadOpRunner:downloadOpRunner
                                                       sentinelOpRunner:sentinelOpRunner];
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
                    [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:nil]; //force slow (network) path
                    [providerMock stub:@selector(downloadImageWithIdentifier:error:)
                             withBlock:^id(NSArray *params) {
                                 [[theValue(downloadOpRunner.isExecuting) should] beTrue];
                                 return nil;
                             }];

                    [[providerMock should] receive:@selector(downloadImageWithIdentifier:error:)];

                    [imageManager imageForIdentifier:identifier placeholder:nil callback:nil];

                    [[theValue(drainOpRunners(20)) should] beTrue];
                });
            });

            describe(@"should ask the cache", ^{
                it(@"for images already in memory)", ^{
                    [[cacheMock should] receive:@selector(getWithKey:onlyMemoryCache:) withArguments:identifier, theValue(YES)];

                    [imageManager imageForIdentifier:identifier placeholder:nil callback:nil];
                });

                it(@"for image on the file system", ^{
                    [cacheMock stub:@selector(getWithKey:onlyMemoryCache:)
                          withBlock:^id(NSArray *params) {
                              if ([[params objectAtIndex:1] boolValue] == YES){

                              } else  {
                                  [[theValue(ioOpRunner.isExecuting) should] beTrue];
                              }
                              return nil;
                          }];
                    [providerMock stub:@selector(downloadImageWithIdentifier:error:) andReturn:quickImage];

                    [[cacheMock should] receive:@selector(getWithKey:onlyMemoryCache:) withArguments:identifier, theValue(NO)];

                    [imageManager imageForIdentifier:identifier placeholder:nil callback:nil];

                    drainOpRunners(20);
                });

                it(@"to store the image when it's downloaded", ^{
                    [cacheMock stub:@selector(getWithKey:onlyMemoryCache:)
                          withBlock:^id(NSArray *params) {
                              return nil;
                          }];
                    [cacheMock stub:@selector(set:forKey:) withBlock:^id(NSArray *params) {
                        [[theValue(ioOpRunner.isExecuting) should] beTrue];
                        return nil;
                    }];
                    [providerMock stub:@selector(downloadImageWithIdentifier:error:) andReturn:quickImage];

                    [[cacheMock should] receive:@selector(set:forKey:) withArguments:quickImage, identifier];

                    [imageManager imageForIdentifier:identifier placeholder:nil callback:nil];

                    drainOpRunners(20);
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

                    [imageManager imageForIdentifier:identifier
                                         placeholder:placeholderImage
                                            callback:^(UIImage *image, BOOL isPlaceholder) {
                                                if (numberOfCalls == 0) {
                                                    [[image should] equal:placeholderImage];
                                                    [[theValue(isPlaceholder) should] beTrue];
                                                    numberOfCalls = 1;
                                                } else if (numberOfCalls == 1) {
                                                    [[image should] equal:quickImage];
                                                    [[theValue(isPlaceholder) should] beFalse];
                                                    numberOfCalls = 2;
                                                }
                                            }];
                    [[theValue(numberOfCalls) should] equal:theValue(1)]; //placeholder invocation

                    drainOpRunners(20);

                    [[theValue(numberOfCalls) should] equal:theValue(2)]; //image invocation
                });

                it(@"in slow path (network) scenario", ^{
                    [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:nil]; //force slow (network) path
                    [providerMock stub:@selector(downloadImageWithIdentifier:error:) andReturn:quickImage];
                    __block NSUInteger numberOfCalls = 0;

                    [imageManager imageForIdentifier:identifier
                                         placeholder:placeholderImage
                                            callback:^(UIImage *image, BOOL isPlaceholder) {
                                                if (numberOfCalls == 0) {
                                                    [[image should] equal:placeholderImage];
                                                    [[theValue(isPlaceholder) should] beTrue];
                                                } else if (numberOfCalls == 1) {
                                                    [[image should] equal:quickImage];
                                                    [[theValue(isPlaceholder) should] beFalse];
                                                }
                                                ++numberOfCalls;
                                            }];

                    [[theValue(numberOfCalls) should] equal:theValue(1)]; //placeholder invocation

                    drainOpRunners(20);

                    [[theValue(numberOfCalls) should] equal:theValue(2)]; //image invocation
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
                                return quickImage;
                            }
                        }];

                        PLImageManagerRequestToken *token = [imageManager imageForIdentifier:identifier
                                                                                 placeholder:nil
                                                                                    callback:nil];

                        [[theValue(token.isReady) should] beFalse];

                        drainOpRunners(20);

                        [[theValue(token.isReady) should] beTrue];
                    });

                    it(@"in slow path (network) scenario", ^{
                        [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:nil]; //force slow (network) path
                        [providerMock stub:@selector(downloadImageWithIdentifier:error:) withBlock:^id(NSArray *params) {
                            return quickImage;
                        }];

                        PLImageManagerRequestToken *token = [imageManager imageForIdentifier:identifier
                                                                                 placeholder:nil
                                                                                    callback:nil];

                        [[theValue(token.isReady) should] beFalse];

                        drainOpRunners(20);

                        [[theValue(token.isReady) should] beTrue];
                    });
                });
            });
        });

        describe(@"multiple images simultanously", ^{
            NSUInteger const maxDownloadCount = 1;

            beforeEach(^{
                [providerMock stub:@selector(maxConcurrentDownloadsCount) andReturn:theValue(maxDownloadCount)];
                imageManager = [[PLImageManager alloc] initWithProvider:providerMock
                                                                  cache:cacheMock
                                                             ioOpRunner:ioOpRunner
                                                       downloadOpRunner:downloadOpRunner
                                                       sentinelOpRunner:sentinelOpRunner];
            });

            it(@"should download all of them", ^{
                NSMutableArray * targets = [NSMutableArray arrayWithObjects:@"0", @"1", @"2", @"3", @"4", nil];

                [providerMock stub:@selector(downloadImageWithIdentifier:error:) withBlock:^id(NSArray *params) {
                    NSString * identifier = [params objectAtIndex:0];
                    [[theValue([targets containsObject:identifier]) should] beTrue];
                    [targets removeObject:identifier];
                    return nil;
                }];

                for (NSString * target in targets) {
                    [imageManager imageForIdentifier:target
                                         placeholder:nil callback:nil];
                }

                drainOpRunners(100);

                [[theValue(targets.count) should] equal:theValue(0)];
            });

            it(@"should download omiting canceled requests", ^{
                NSMutableArray * targets = [NSMutableArray arrayWithObjects:@"0", @"1", @"2", @"3", @"4", nil];
                NSMutableArray * tokens = [NSMutableArray arrayWithCapacity:targets.count];
                NSMutableArray * canceled = [NSMutableArray arrayWithObjects:@"2", @"3", nil];

                [providerMock stub:@selector(downloadImageWithIdentifier:error:) withBlock:^id(NSArray *params) {
                    NSString * identifier = [params objectAtIndex:0];
                    [[theValue([targets containsObject:identifier]) should] beTrue];
                    [[theValue([canceled containsObject:identifier]) should] beFalse];
                    [targets removeObject:identifier];
                    return nil;
                }];

                for (NSString *target in targets) {
                    PLImageManagerRequestToken *token = [imageManager imageForIdentifier:target
                                                                             placeholder:nil
                                                                                callback:nil];
                    if([canceled containsObject:target]){
                        [tokens addObject:token];
                    }
                }

                for (PLImageManagerRequestToken * token in tokens) {
                    [token cancel];
                }
                [targets removeObjectsInArray:canceled];

                drainOpRunners(100);

                [[theValue(targets.count) should] equal:theValue(0)];
            });

            it(@"should download canceled requests when rerequested", ^{
                NSMutableArray * targets = [NSMutableArray arrayWithObjects:@"0", @"1", @"2", @"3", @"4", nil];
                NSMutableArray * tokens = [NSMutableArray arrayWithCapacity:targets.count];
                NSMutableArray * canceled = [NSMutableArray arrayWithObjects:@"2", @"3", nil];

                [providerMock stub:@selector(downloadImageWithIdentifier:error:) withBlock:^id(NSArray *params) {
                    NSString * identifier = [params objectAtIndex:0];
                    [[theValue([targets containsObject:identifier]) should] beTrue];
                    [targets removeObject:identifier];
                    return nil;
                }];

                for (NSString *target in targets) {
                    PLImageManagerRequestToken *token = [imageManager imageForIdentifier:target
                                                                             placeholder:nil
                                                                                callback:nil];
                    if([canceled containsObject:target]){
                        [tokens addObject:token];
                    }
                }

                for (PLImageManagerRequestToken * token in tokens) {
                    [token cancel];
                }

                for (NSString *target in canceled) {
                    [imageManager imageForIdentifier:target
                                         placeholder:nil
                                            callback:nil];
                }

                drainOpRunners(100);

                [[theValue(targets.count) should] equal:theValue(0)];
            });

            it(@"should download repeated requests even when partialy canceled", ^{
                NSMutableArray * targets = [NSMutableArray arrayWithObjects:@"0", @"1", @"2", @"3", @"4", nil];
                NSMutableArray * tokens = [NSMutableArray arrayWithCapacity:targets.count];
                NSMutableArray * canceled = [NSMutableArray arrayWithObjects:@"2", @"3", nil];

                [providerMock stub:@selector(downloadImageWithIdentifier:error:) withBlock:^id(NSArray *params) {
                    NSString * identifier = [params objectAtIndex:0];
                    [[theValue([targets containsObject:identifier]) should] beTrue];
                    [targets removeObject:identifier];
                    return nil;
                }];

                for (NSString *target in targets) {
                    PLImageManagerRequestToken *token = [imageManager imageForIdentifier:target
                                                                             placeholder:nil
                                                                                callback:nil];
                    if([canceled containsObject:target]){
                        [tokens addObject:token];
                    }
                }

                for (NSString *target in canceled) {
                    [imageManager imageForIdentifier:target
                                         placeholder:nil
                                            callback:nil];
                }

                for (PLImageManagerRequestToken * token in tokens) {
                    [token cancel];
                }

                drainOpRunners(100);

                [[theValue(targets.count) should] equal:theValue(0)];
            });

            it(@"should download repeated requests only once", ^{
                NSMutableArray * targets = [NSMutableArray arrayWithObjects:@"0", @"1", @"2", @"3", @"4", nil];
                NSMutableArray * repeated = [NSMutableArray arrayWithObjects:@"0", @"3", nil];

                [providerMock stub:@selector(downloadImageWithIdentifier:error:) withBlock:^id(NSArray *params) {
                    NSString * identifier = [params objectAtIndex:0];
                    [[theValue([targets containsObject:identifier]) should] beTrue];
                    [targets removeObject:identifier];
                    return nil;
                }];

                for (NSString *target in targets) {
                    [imageManager imageForIdentifier:target
                                         placeholder:nil
                                            callback:nil];
                }

                for (NSString *target in repeated) {
                    [imageManager imageForIdentifier:target
                                         placeholder:nil
                                            callback:nil];
                }

                drainOpRunners(100);

                [[theValue(targets.count) should] equal:theValue(0)];
            });
//
////                //TODO: write a "weak" test for deferCurrentDownloads
//
//
//                describe(@"FIFO order taking cancels into account", ^{
//                    it(@"for non-repeating requests", ^{
//                        [checkerLock lock];
//                        [downloadLock lock];
//                        PLImageManagerRequestToken * token = nil;
//                        [imageManager imageForIdentifier:@"a0"
//                                             placeholder:nil callback:nil];
//                        token = [imageManager imageForIdentifier:@"a1"
//                                                     placeholder:nil callback:nil];
//                        [imageManager imageForIdentifier:@"a2"
//                                             placeholder:nil callback:nil];
//                        [downloadLock unlock];
//
//                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
//                        [[lastDownloaded should] equal:@"a0"];
//
//                        [token cancel];
//
//                        [downloadLock lock];
//                        [downloadLock signal];
//                        [downloadLock unlock];
//
//                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
//                        [[lastDownloaded should] equal:@"a2"];
//
//                        [downloadLock lock];
//                        [downloadLock signal];
//                        [downloadLock unlock];
//
//                        lastDownloaded = nil;
//                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(NO)];//should time out
//                        [[theValue(lastDownloaded == nil) should] equal:theValue(YES)];
//
//                        [checkerLock unlock];
//                    });
//
//                    it(@"for repeating requests", ^{
//                        [checkerLock lock];
//                        [downloadLock lock];
//                        PLImageManagerRequestToken * token = nil;
//                        [imageManager imageForIdentifier:@"a0"
//                                             placeholder:nil callback:nil];
//                        token = [imageManager imageForIdentifier:@"a1"
//                                                     placeholder:nil callback:nil];
//                        [imageManager imageForIdentifier:@"a2"
//                                             placeholder:nil callback:nil];
//                        [imageManager imageForIdentifier:@"a1"
//                                             placeholder:nil callback:nil];
//                        [downloadLock unlock];
//
//                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
//                        [[lastDownloaded should] equal:@"a0"];
//
//                        [token cancel];
//
//                        [downloadLock lock];
//                        [downloadLock signal];
//                        [downloadLock unlock];
//
//                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
//                        [[lastDownloaded should] equal:@"a1"];
//
//                        [downloadLock lock];
//                        [downloadLock signal];
//                        [downloadLock unlock];
//
//                        [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]) should] equal:theValue(YES)];//should be signaled
//                        [[lastDownloaded should] equal:@"a2"];
//
//                        [downloadLock lock];
//                        [downloadLock signal];
//                        [downloadLock unlock];
//
//                        [checkerLock unlock];
//                    });
//                });
//            });
        });
    });

    describe(@"clearing", ^{
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
            imageManager = [[PLImageManager alloc] initWithProvider:providerMock cache:cacheMock ioOpRunner:NULL downloadOpRunner:NULL sentinelOpRunner:NULL];
        });

        it(@"a image should call the proper image cache methods", ^{
            NSString * const identifier = @"example_id";
            [[[cacheMock should] receive] removeImageWithKey:identifier];

            [imageManager clearCachedImageForIdentifier:identifier];
        });

        it(@"all images it should call the proper image cache methods", ^{
            [[[cacheMock should] receive] clearMemoryCache];
            [[[cacheMock should] receive] clearFileCache];

            [imageManager clearCache];
        });
    });
});

SPEC_END