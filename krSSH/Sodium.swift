//
//  Sodium.swift
//  Kryptonite
//
//  Created by Kevin King on 9/20/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import Sodium

struct SodiumInitializationFailure:Error{}

private var sharedSodium : Sodium?
class KRSodium {
    class func shared() throws -> Sodium {
        if let sodium = sharedSodium {
            return sodium
        }
        guard let sodium = Sodium() else {
            throw SodiumInitializationFailure()
        }
        return sodium
    }
}
