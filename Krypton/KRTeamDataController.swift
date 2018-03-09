//
//  KRTeamDataController.swift
//  Krypton
//
//  Created by Alex Grinman on 10/25/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

protocol KRTeamDataControllerDelegate {
    var mutex:Mutex { get }
    var identity:TeamIdentity { get set }
    var refreshControl:UIRefreshControl? { get }
    var controller:UIViewController { get }
    
    func didUpdateTeamIdentity()
    func update(identity:TeamIdentity)
    
    func update(billingInfo: SigChainBilling.BillingInfo)
}

extension KRTeamDataControllerDelegate {
    
    func fetchTeamUpdates() {
        self.mutex.lock()
        
        dispatchAsync {
            defer { self.mutex.unlock() }
            
            // subscribe to push just in case
            if let pushToken = UserDefaults.group?.string(forKey: Constants.pushTokenKey) {
                do {
                    try TeamService.shared().subscribeToPushSync(with: pushToken)
                }
                catch {
                    log("team push subscription failed: \(error)", .error)
                }
            }
            
            // get billing info
            do {
                if try self.identity.dataManager.withTransaction{ return try self.identity.isAdmin(dataManager: $0) } {
                    switch try TeamService.shared().getBillingInfoSync() {
                    case .error(let e):
                        log("failed to get billing info: \(e)", .error)
                    case .result(let billingInfo):
                        self.update(billingInfo: billingInfo)
                    }
                }
            } catch {
                log("error getting billing info: \(error)", .error)
            }
            
            // read to main chain
            do {
                let result = try TeamService.shared().getVerifiedTeamUpdatesSync()
                dispatchMain { self.refreshControl?.endRefreshing() }
                
                switch result {
                case .error(let e):
                    throw e
                    
                case .result(let service):
                    do {
                        try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                    } catch {
                        self.controller.showWarning(title: "Error", body: "Could not save team updates. \(error).")
                        dispatchMain { self.refreshControl?.endRefreshing() }
                        return
                    }
                    
                    self.update(identity: service.teamIdentity)
                    self.didUpdateTeamIdentity()
                }
            } catch {
                dispatchMain { self.refreshControl?.endRefreshing() }
                self.controller.showWarning(title: "Error", body: "Could not fetch new team updates. \(error).")
            }
        }
    }
}

