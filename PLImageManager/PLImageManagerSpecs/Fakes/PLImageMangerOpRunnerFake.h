//
// Created by Antoni Kędracki, Polidea
//

#import <Foundation/Foundation.h>
#import "PLImageManagerOpRunner.h"

@interface PLImageMangerOpRunnerFake : PLImageManagerOpRunner

@property (nonatomic, assign, readonly) BOOL isExecuting;
- (BOOL)step;

@end