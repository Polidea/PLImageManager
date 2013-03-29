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

#import "PLImageManagerOpRunner.h"


NSUInteger const PLImageManagerOpRunnerUnlimited = NSOperationQueueDefaultMaxConcurrentOperationCount;

@implementation PLImageManagerOpRunner {
@private
    NSOperationQueue *queue;
}

- (id)init {
    self = [super init];
    if (self) {
        queue = [NSOperationQueue new];
    }

    return self;
}

- (void)addOperation:(NSOperation *)operation {
    [queue addOperation:operation];
}

- (void)setMaxConcurrentOperationsCount:(NSUInteger)maxConcurrentOperationsCount {
    queue.maxConcurrentOperationCount = maxConcurrentOperationsCount;
}

- (void)setName:(NSString *)name {
    queue.name = name;
}

- (NSUInteger)maxConcurrentOperationsCount {
    return queue.maxConcurrentOperationCount;
}

- (NSString *)name {
    return queue.name;
}

@end