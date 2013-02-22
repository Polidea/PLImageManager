#import <Kiwi/Kiwi.h>
#import "PLImageManager.h"
#import "PLImageCache.h"
#import "UIImage+RandomImage.h"

@interface PLImageManager ()

- (id)initWithProvider:(id <PLImageManagerProvider>)aProvider cache:(PLImageCache *)aCache;

@end

SPEC_BEGIN(PLImageManagerSpecs)

describe(@"PLImageManager", ^{
    __block UIImage * quickImage;

    beforeAll(^{
        quickImage = [UIImage randomImage];
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

    describe(@"requesting download", ^{
        __block Class identifierClass;
        __block NSString * identifier = @"example_id";
        __block PLImageManager * imageManager;
        __block id providerMock;
        __block id cacheMock;

        beforeAll(^{
            identifierClass = [identifier class];
        });

        beforeEach(^{
            providerMock = [KWMock nullMockForProtocol:@protocol(PLImageManagerProvider)];
            cacheMock = [KWMock nullMockForClass:[PLImageCache class]];
            [providerMock stub:@selector(maxConcurrentDownloadsCount) andReturn:theValue(1)];
            [providerMock stub:@selector(identifierClass) andReturn:theValue(identifierClass)];
            [providerMock stub:@selector(keyForIdentifier:) andReturn:identifier];
            imageManager = [[PLImageManager alloc] initWithProvider:providerMock cache:cacheMock];
        });

        describe(@"should ask the provider", ^{
            beforeAll(^{
                [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:quickImage]; //force quick path
            });

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

                [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:nil]; //force slow path
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
            beforeAll(^{
                [cacheMock stub:@selector(getWithKey:onlyMemoryCache:) andReturn:quickImage]; //force quick path
            });

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
    });
});

SPEC_END