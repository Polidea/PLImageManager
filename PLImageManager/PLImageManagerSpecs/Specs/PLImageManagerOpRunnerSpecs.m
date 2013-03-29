#import <Kiwi/Kiwi.h>
#import <libkern/OSAtomic.h>
#import "PLImageManagerOpRunner.h"

SPEC_BEGIN(PLImageManagerOpRunnerSpecs)

describe(@"PLImageManagerOpRunner", ^{
    __block PLImageManagerOpRunner * runner;

    beforeEach(^{
        runner = [PLImageManagerOpRunner new];
    });

    describe(@"should perform the queued operation", ^{
        it(@"on not more then maxConcurrentDownloadsCount threads", ^{
            NSUInteger const maxDownloadCount = 5;
            runner.maxConcurrentOperationsCount = maxDownloadCount;

            NSCondition *workLock = [NSCondition new];
            NSCondition *checkerLock = [NSCondition new];
            __block NSInteger runningDownloads = 0;
            __block NSInteger downloadsLeft = 10;

            NSOperation * (^newOp)() = ^{
                return [NSBlockOperation blockOperationWithBlock:^{
                    OSAtomicIncrement32(&runningDownloads);
                    //notify checker
                    [checkerLock lock];
                    [checkerLock signal];
                    [checkerLock unlock];
                    //block yourself
                    [workLock lock];
                    [workLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                    [workLock unlock];

                    OSAtomicDecrement32(&runningDownloads);
                    OSAtomicDecrement32(&downloadsLeft);

                    //notify checker once more
                    [checkerLock lock];
                    [checkerLock signal];
                    [checkerLock unlock];
                }];
            };

            //test
            [checkerLock lock];
            for (int i = downloadsLeft; i > 0; --i) {
                [runner addOperation:newOp()];
            }
            [checkerLock unlock];

            while (downloadsLeft > 0) {
                [checkerLock lock];
                [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]]) should] equal:theValue(YES)];//should be signaled
                [[theValue(runningDownloads) should] beLessThanOrEqualTo:theValue(maxDownloadCount)];
                [checkerLock unlock];
            }

            //cleanup
            [workLock lock];
            [workLock broadcast];
            [workLock unlock];
            [checkerLock lock];
            [checkerLock broadcast];
            [checkerLock unlock];
        });

        it(@"in FIFO order", ^{
            NSUInteger const maxDownloadCount = 1;
            runner.maxConcurrentOperationsCount = maxDownloadCount;

            NSCondition *workLock = [NSCondition new];
            NSCondition *checkerLock = [NSCondition new];
            __block NSInteger runningDownloads = 0;
            __block NSInteger downloadsLeft = 10;
            __block NSUInteger lastPerformed;

            NSOperation * (^newOp)(NSUInteger) = ^(NSUInteger i){
                return [NSBlockOperation blockOperationWithBlock:^{
                    [workLock lock];
                    lastPerformed = i;
                    [checkerLock lock];
                    [checkerLock signal];
                    [checkerLock unlock];
                    [workLock wait];
                    [workLock unlock];
                }];
            };

            //test
            [checkerLock lock];
            [workLock lock];
            for (int i = downloadsLeft; i > 0; --i) {
                [runner addOperation:newOp(i)];
            }
            [workLock unlock];

            while (downloadsLeft > 0) {
                [[theValue([checkerLock waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]]) should] equal:theValue(YES)];//should be signaled
                [[theValue(lastPerformed) should] beLessThanOrEqualTo:theValue(downloadsLeft)];
                --downloadsLeft;

                [workLock lock];
                [workLock signal];
                [workLock unlock];
            }
            [checkerLock unlock];

            //cleanup
            [workLock lock];
            [workLock broadcast];
            [workLock unlock];
            [checkerLock lock];
            [checkerLock broadcast];
            [checkerLock unlock];
        });
    });

});

SPEC_END