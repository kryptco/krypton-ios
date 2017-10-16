//
//  AuthenticatedEncryption.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/3/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import CommonCrypto
import Sodium

extension Box.PublicKey {
    func wrap(to pk: Box.PublicKey) throws -> Data {
        guard let wrappedPublicKey = KRSodium.shared().box.seal(message: self, recipientPublicKey: pk)
        else {
            throw CryptoError.encrypt
        }
        return wrappedPublicKey
    }
}

