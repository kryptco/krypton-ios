//
//  CommunicationActivity.swift
//  Krypton
//
//  Created by Kevin King on 12/3/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

enum CommunicationMedium:String {
    case bluetooth
    case remoteNotification
    case sqs
    case internalPending
}

class CommunicationActivity {
    private var activtyByMedium : [CommunicationMedium:Date] = [:]
    private let created = Date().timeIntervalSince1970
    func used(medium: CommunicationMedium) {
        activtyByMedium[medium] = Date()
    }

    func isInactive(on medium: CommunicationMedium) -> Bool {
        guard Date().timeIntervalSince1970 - created >= Properties.communicationActivityTimeout else {
            return false
        }

        guard let lastActivity = activtyByMedium[medium] else {
            return true
        }

        guard let lastOtherActivity = activtyByMedium.filter({ $0.key != medium }).map({ $0.value.timeIntervalSince1970 }).max() else {
            return false
        }

        return lastOtherActivity - lastActivity.timeIntervalSince1970 >= Properties.communicationActivityTimeout
    }

    func everActive() -> Bool {
        return activtyByMedium.count > 0
    }
}
