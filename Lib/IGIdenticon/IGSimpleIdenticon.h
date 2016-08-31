//
//  IGSimpleIdenticon.h
//  IGIdenticon
//
//  Created by Evgeniy Yurtaev on 7/20/13.
//  Copyright (c) 2013 Evgeniy Yurtaev. All rights reserved.
//

#import "IGImageProducing.h"
#import "IGHashFunctions.h"
#import "IGImageGenerator.h"

@interface IGSimpleIdenticon : NSObject <IGImageProducing>

+ (UIImage *)from:(NSString *)string size:(CGSize)size;

@end
