//
//  PLAppDelegate.h
//  PLImageManagerExample
//
//  Created by Antoni Kedracki on 2/8/13.
//  Copyright (c) 2013 Polidea. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PLImageManager.h"

@class PLTileManager;

@interface PLAppDelegate : UIResponder <UIApplicationDelegate>

@property(strong, nonatomic) UIWindow *window;
@property(strong, readonly) PLTileManager *tileManager;

+ (PLAppDelegate *)appDelegate;

@end
