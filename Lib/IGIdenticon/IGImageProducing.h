//
//  IGImageProducing.h
//  IGIdenticon
//
//  Created by Evgeniy Yurtaev on 27/07/15.
//  Copyright (c) 2015 Evgeniy Yurtaev. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreGraphics/CGGeometry.h>

@protocol IGImageProducing <NSObject>

- (UIImage *)imageFromNumber:(uint32_t)number size:(CGSize)size;

@end
