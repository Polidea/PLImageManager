//
// Created by antoni on 2/8/13.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import <Foundation/Foundation.h>
#import "PLImageManager.h"


@interface PLTileManager : PLImageManager

- (void)tileForZoomLevel:(NSUInteger)zoom latDeg:(double)latDeg lonDeg:(double)lonDeg callback:(void (^)(UIImage *, NSUInteger, double, double))callback;
- (void)tileForZoomLevel:(NSUInteger)zoom tileX:(NSInteger)tileX tileY:(NSInteger)tileY callback:(void (^)(UIImage *, NSUInteger, NSInteger, NSInteger))callback;

@end