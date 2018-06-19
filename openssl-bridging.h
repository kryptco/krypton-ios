//
//  openssl-bridging.h
//  Krypton
//
//  Created by Alex Grinman on 5/2/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

#ifndef openssl_bridging_h
#define openssl_bridging_h

#define OPENSSL_NO_RSA

#import <openssl/opensslv.h>
#import <openssl/x509.h>
#import <openssl/x509v3.h>
#import <openssl/err.h>

const ASN1_ITEM* X509_CINF_RPTR() {
    return ASN1_ITEM_rptr(X509_CINF);
}

#endif /* openssl_bridging_h */
