//
//  IGHashFunctions.m
//  IGIdenticon
//
//  Created by Evgeniy Yurtaev on 27/07/15.
//  Copyright (c) 2015 Evgeniy Yurtaev. All rights reserved.
//

#import "IGHashFunctions.h"

uint32_t IGJenkinsHashFromData(NSData *data)
{
    uint32_t hash = 0;
    const unsigned char *bytes = data.bytes;

    for(NSUInteger i = 0; i < [data length]; ++i) {
        hash += bytes[i];
        hash += (hash << 10);
        hash ^= (hash >> 6);
    }
    hash += (hash << 3);
    hash ^= (hash >> 11);
    hash += (hash << 15);

    return hash;
}
