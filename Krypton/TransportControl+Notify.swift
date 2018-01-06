//
//  TransportControl+Notify.swift
//  Krypton
//
//  Created by Kevin King on 11/9/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

extension TransportControl {
    func addTransports(_ transports: inout [TransportMedium]) {
        transports.append(SQSManager(handler: handle))
    }
    func isBluetoothPoweredOn() -> Bool {
        return false
    }
}
