//
//  TOTP.swift
//  KryptCodes
//
//  Created by Alex Grinman on 11/5/17.
//  Copyright © 2017 Alex Grinman. All rights reserved.
//

import Foundation

func TOTP(secret:[UInt8], digits:HOTPDigits, period:Int, time:Date) throws -> HOTPCode {
    let timeStep = UInt64(time.timeIntervalSince1970/Double(period))
    let counter = timeStep.eightByteCounter
    
    return try HOTP(secretKey: secret, counter: counter, digits: digits)
}
