//
// Created by Antoni Kędracki, Polidea
//

#import "PLImageMangerOpRunnerFake.h"


@implementation PLImageMangerOpRunnerFake {
    NSMutableArray *ops;
    NSOperationQueue *executionQueue;
    NSInteger maxConcurrentOperationsCount;
    NSString *name;
    BOOL isExecuting;
}

- (id)init {
    self = [super init];
    if (self) {
        ops = [NSMutableArray new];
        executionQueue = [NSOperationQueue new];
    }

    return self;
}


- (NSUInteger)maxConcurrentOperationsCount {
    return maxConcurrentOperationsCount;
}

- (void)setMaxConcurrentOperationsCount:(NSUInteger)aMaxConcurrentOperationsCount {
    maxConcurrentOperationsCount = aMaxConcurrentOperationsCount;
}

- (NSString *)name {
    return name;
}

- (void)setName:(NSString *)aName {
    name = aName;
}

- (void)addOperation:(NSOperation *)operation {
    [ops addObject:operation];
}

- (BOOL)step {
    if (ops.count == 0) {
        return NO;
    }

    NSOperationQueuePriority highestPriority = NSIntegerMin;
    NSInteger highestPriorityPosition = -1;

    for (int j = 0; j < ops.count; j++) {
        NSOperation *op = [ops objectAtIndex:j];
//        NSLog(@"ready: %d canceled: %d finished: %d", op.isReady, op.isCancelled, op.isFinished);
        if (op.isReady && op.queuePriority > highestPriority) {
            highestPriority = op.queuePriority;
            highestPriorityPosition = j;
        }
    }

    if (highestPriorityPosition != -1) {
        NSOperation *op = [ops objectAtIndex:highestPriorityPosition];
//        NSLog(@"[%@] executing op: %@", name, op);
//        [executionQueue addOperations:@[op] waitUntilFinished:YES];

        isExecuting = YES;
        [op start];
        isExecuting = NO;
//        while (!op.isFinished) {
//
//        }
        [ops removeObjectAtIndex:highestPriorityPosition];
        return YES;
    } else {
        return ops.count > 0;
    }
}

- (BOOL)isExecuting {
    return isExecuting;
}

@end