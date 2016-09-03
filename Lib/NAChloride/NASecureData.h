//
//  NASecureData.h
//  NAChloride
//
//  Created by Gabriel on 6/19/15.
//  Copyright (c) 2015 Gabriel Handford. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NAInterface.h"

typedef NS_ENUM (NSInteger, NASecureDataProtection) {
  NASecureDataProtectionReadWrite = 0, // Default no protection
  NASecureDataProtectionReadOnly,
  NASecureDataProtectionNoAccess,
};

/*!
 Secure memory using libsodium.
 */
@interface NASecureData : NSMutableData // Subclassing for convienience

@property (nonatomic) NASecureDataProtection protection;

/*!
 Secure and read only data.
 */
+ (instancetype)secureReadOnlyDataWithLength:(NSUInteger)length completion:(NADataCompletion)completion;

/*!
 Secure data is has read/write protection in this block.
 */
- (void)readWrite:(void (^)(NASecureData *secureData))completion;

/*!
 Truncate.
 */
- (NASecureData *)truncate:(NSUInteger)length;

@end


// Optional building of secure NSData
NSMutableData *NAData(BOOL secure, NSUInteger length, NADataCompletion completion);


@interface NSMutableData (NASecureData)

- (NSData *)na_truncate:(NSUInteger)length;

@end