//
//  Connectivity.swift
//  Kryptonite
//
//  Created by Alex Grinman on 12/1/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
//import Reachability

class Connectivity {
    
    static let host = "https://aws.amazon.com"
    
    var presenter:UIViewController
    
    var reachability:AWSKSReachability?
    
    init(presenter:UIViewController) {
        self.presenter = presenter
        
        reachability = AWSKSReachability(toHost: Connectivity.host)
        reachability?.onInitializationComplete = {(reachability) -> Void in
            self.reachabilityChanged(r: reachability)
        }
        
        reachability?.onReachabilityChanged = reachabilityChanged
    }
    
    func reachabilityChanged(r:AWSKSReachability?) {
        // reachable, all set
        if r?.reachable == true {
            return
        }
        
        log("internet offline")
        
        // at least we have bluetooth
        if (TransportControl.shared.transport(for: .bluetooth) as? BluetoothManager)?.bluetoothDelegate.central?.state == .poweredOn {
            return
        }
        
        log("bluetooth off")
        
        //otherwise, completely unreachable
        presenter.showSettings(with: "Not connected to internet and Bluetooth", message: "Please make sure that either you are connected to the internet or that Bluetooth is turned on. Host \(Connectivity.host) unreachable.", then: nil)
        
    }
}
