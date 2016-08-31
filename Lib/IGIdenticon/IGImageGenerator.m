//
//  IGImageGenerator.m
//  IGIdenticon
//
//  Created by Evgeniy Yurtaev on 29/07/15.
//  Copyright (c) 2015 Evgeniy Yurtaev. All rights reserved.
//

#import "IGImageGenerator.h"

@interface IGImageGenerator ()

@property (strong, nonatomic) id<IGImageProducing> imageProducer;

@property (assign, nonatomic) uint32_t (*hashFunction)(NSData *__strong);

@end

@implementation IGImageGenerator

- (instancetype)initWithImageProducer:(id<IGImageProducing>)imageProducer hashFunction:(uint32_t (*)(NSData *__strong))hashFunction
{
    NSParameterAssert(imageProducer);
    NSParameterAssert(hashFunction);

    self = [super init];
    if (self) {
        self.imageProducer = imageProducer;
        self.hashFunction = hashFunction;
    }

    return self;
}

- (UIImage *)imageFromUInt32:(uint32_t)number size:(CGSize)size
{
    UIImage *image = [self.imageProducer imageFromNumber:number size:size];

    return image;
}

- (UIImage *)imageFromData:(NSData *)data size:(CGSize)size
{
    NSParameterAssert(data);

    uint32_t hash = self.hashFunction(data);
    UIImage *image = [self imageFromUInt32:hash size:size];

    return image;
}

- (UIImage *)imageFromString:(NSString *)string size:(CGSize)size
{
    NSParameterAssert(string);

    NSData *data = [string dataUsingEncoding:NSUTF16StringEncoding];
    UIImage *image = [self imageFromData:data size:size];

    return image;
}

@end
