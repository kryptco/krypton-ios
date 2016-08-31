//
//  IGGitHubIdenticon.m
//  IGIdenticon
//
//  Created by Evgeniy Yurtaev on 06.05.14.
//  Copyright (c) 2014 Evgeniy Yurtaev. All rights reserved.
//

#import "IGGitHubIdenticon.h"
#import <CoreGraphics/CGBase.h>

@implementation IGGitHubIdenticon

- (UIImage *)imageFromNumber:(uint32_t)number size:(CGSize)size
{
    NSInteger blue = (number >> 16) & 31;
    NSInteger green = (number >> 21) & 31;
    NSInteger red = (number >> 27) & 31;

    UIColor *foregroundColor = [UIColor colorWithRed:(red * 8) / 255.0f green:(green * 8) / 255.0f blue:(blue * 8) / 255.0f alpha:1];

    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetShouldAntialias(context, NO);

    [foregroundColor setFill];
    CGSize cellSize = CGSizeMake(size.width / 5, size.height / 5);
    for (NSUInteger i = 0; i < 15; ++i) {
        if ((number >> i) & 0x1u) {
            NSUInteger drawPositionX = i % 3;
            NSUInteger drawPositionY = i / 3;
            
            CGContextFillRect(context, CGRectMake(drawPositionX * cellSize.width, drawPositionY * cellSize.height, cellSize.width, cellSize.height));
            if (drawPositionX != 4 - drawPositionX) {
                CGContextFillRect(context, CGRectMake((4 - drawPositionX) * cellSize.width, drawPositionY * cellSize.height, cellSize.width, cellSize.height));
            }
        }
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

@end
