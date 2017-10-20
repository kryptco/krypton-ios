//
//  Sodium.swift
//  Kryptonite
//
//  Created by Kevin King on 9/20/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import Sodium

typealias SodiumSignPublicKey = Sign.PublicKey
typealias SodiumSignSecretKey = Sign.SecretKey
typealias SodiumSignKeyPair = Sign.KeyPair

typealias SodiumBoxPublicKey = Box.PublicKey
typealias SodiumBoxKeyPair = Box.KeyPair

typealias SodiumSecretBoxKey = SecretBox.Key

class KRSodium {
    class func instance() -> Sodium {
        return Sodium()
    }
}
