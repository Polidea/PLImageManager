#import <Kiwi/Kiwi.h>
#import <OCMock-iPhone/OCMock.h>
#import "PLImageManager.h"

@interface PLImageManager ()

- (id)initWithProvider:(id <PLImageManagerProvider>)aProvider cache:(PLImageCache *)aCache;

@end

SPEC_BEGIN(PLImageManagerSpecs)

describe(@"PLImageManager", ^{
    describe(@"during creation", ^{
        __block PLImageManager * imageManager;
        
        it(@"should complain about missing provider", ^{
            [[theBlock(^{
                imageManager = [[PLImageManager alloc] initWithProvider:nil];
            }) should] raiseWithName:@"InvalidArgumentException"];
        });
        
        it(@"should ask the provider for the maxConcurrentDownloadsCount", ^{
            id provider = [OCMockObject niceMockForProtocol:@protocol(PLImageManagerProvider)];
            
            [[provider expect] maxConcurrentDownloadsCount];
            
            imageManager = [[PLImageManager alloc] initWithProvider:provider];
            
            [provider verify];
        });
    });
    
    
});

SPEC_END