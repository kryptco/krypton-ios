//
//  NASecureData.m
//  NAChloride
//
//  Created by Gabriel on 6/19/15.
//  Copyright (c) 2015 Gabriel Handford. All rights reserved.
//

#import "NASecureData.h"

#import "NAInterface.h"

#import <libsodium/sodium.h>

@interface NASecureData ()
@property void *secureBytes;
@property NSUInteger secureLength;
@end

@implementation NASecureData

+ (void)initialize { NAChlorideInit(); }

- (instancetype)initWithLength:(NSUInteger)length {
  if ((self = [super init])) {
    NAChlorideInit(); // It's already init'ed, but just to be safe
    _secureLength = length;
    _secureBytes = sodium_malloc(length);
  }
  return self;
}

+ (instancetype)secureReadOnlyDataWithLength:(NSUInteger)length completion:(NADataCompletion)completion {
  NASecureData *secureData = [[NASecureData alloc] initWithLength:length];
  completion(secureData.secureBytes, secureData.length);
  secureData.protection = NASecureDataProtectionReadOnly;
  return secureData;
}

- (void)dealloc {
  sodium_free(_secureBytes);
}

- (void)setProtection:(NASecureDataProtection)protection {
  switch (protection) {
    // Keep these case statements order from most secure to least secure in case some jerk removes a break;
    case NASecureDataProtectionReadWrite: sodium_mprotect_readwrite(_secureBytes); break;
    case NASecureDataProtectionReadOnly: sodium_mprotect_readonly(_secureBytes); break;
    case NASecureDataProtectionNoAccess: sodium_mprotect_noaccess(_secureBytes); break;
  }
}

- (NSUInteger)length {
  return _secureLength;
}

- (const void *)bytes {
  return _secureBytes;
}

- (void *)mutableBytes {
  return _secureBytes;
}

- (void)readWrite:(void (^)(NASecureData *secureData))completion {
  NASecureDataProtection protection = self.protection;
  self.protection = NASecureDataProtectionReadWrite;
  completion(self);
  self.protection = protection;
}

- (NASecureData *)truncate:(NSUInteger)length {
  if (length == 0) return self;
  return [NASecureData secureReadOnlyDataWithLength:(self.length - length) completion:^(void *bytes, NSUInteger length) {
    memcpy(bytes, self.bytes, length);
  }];
}

- (NSData *)na_truncate:(NSUInteger)length { return [self truncate:length]; }

@end

NSMutableData *NAData(BOOL secure, NSUInteger length, NADataCompletion completion) {
  if (!secure) {
    NSMutableData *data = [NSMutableData dataWithLength:length];
    completion([data mutableBytes], length);
    return data;
  } else {
    return [NASecureData secureReadOnlyDataWithLength:length completion:completion];
  }
}

@implementation NSMutableData (NASecureData)

- (NSData *)na_truncate:(NSUInteger)length {
  if (length == 0) return self;
  return [NSData dataWithBytes:self.bytes length:self.length - length];
}

@end
