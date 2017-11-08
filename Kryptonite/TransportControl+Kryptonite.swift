//
//  TransportControl+Kryptonite.swift
//  Kryptonite
//
//  Created by Kevin King on 11/9/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import CoreBluetooth

extension TransportControl {
    func addTransports(_ transports: inout [TransportMedium]) {
        transports.append(BluetoothManager(handler: handle))
        transports.append(SQSManager(handler: handle))
    }
    func isBluetoothPoweredOn() -> Bool {
        if (TransportControl.shared.transport(for: .bluetooth) as? BluetoothManager)?.bluetoothDelegate.peripheralManager?.state == .poweredOn {
            return true
        }
        return false
    }
}
