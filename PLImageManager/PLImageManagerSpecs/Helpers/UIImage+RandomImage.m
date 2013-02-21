//
// Created by antoni on 2/21/13.
//
// To change the template use AppCode | Preferences | File Templates.
//

#import "UIImage+RandomImage.h"
#import <QuartzCore/QuartzCore.h>


@implementation UIImage (RandomImage)

+(UIImage *) randomImage{
    return [self randomImageWithSize:CGSizeMake(32, 32)];
}

+(UIImage *) randomImageWithSize:(CGSize)size {
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [[UIColor redColor] CGColor]);
    CGContextFillRect(context, rect);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end