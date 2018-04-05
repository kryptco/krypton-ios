//
//  TeamDataTransaction.swift
//  Krypton
//
//  Created by Alex Grinman on 3/15/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

class TeamDataTransaction {
    
    private let identity:TeamIdentity
    
    enum DBType {
        case mainApp
        case notifyExt
                
        func name(for identity:Data) -> String {
            switch self {
            case .mainApp:
                return identity.toBase64(true)
                
            case .notifyExt:
                return "\(identity.toBase64(true))_notify"
            }
        }
    }
    
    init(identity:TeamIdentity) {
        self.identity = identity
    }
    
    func withTransaction<T>(dbType: DBType = InstanceDBType, _ transaction:(TeamDataManager) throws -> T) throws -> T {
        let dataManager = try TeamDataManager(name: dbType.name(for: identity.publicKey))
        
        do {
            let result:T = try transaction(dataManager)
            try dataManager.saveContext()
            return result
        } catch {
            dataManager.rollbackContext()
            throw error
        }
    }
    
    
    func withReadOnlyTransaction<T>(dbType: DBType = InstanceDBType, _ transaction:(TeamDataManager) throws -> T) throws -> T {
        let dataManager = try TeamDataManager(name: dbType.name(for: identity.publicKey), readOnly: true)
        let result:T = try transaction(dataManager)
        return result
    }
}
