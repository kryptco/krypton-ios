//
//  Sodium.swift
//  Kryptonite
//
//  Created by Kevin King on 9/20/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import Sodium

class KRSodium {
    class func shared() -> Sodium {
        return Sodium()
    }
}
