//
//  TeamService+Billing.swift
//  Krypton
//
//  Created by Alex Grinman on 2/20/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

// Read Billing info

extension TeamService {
    func getBillingInfoSync() throws -> TeamServiceResult<SigChainBilling.BillingInfo> {
        let signedMessage = try teamIdentity.sign(body: .readBillingInfo(SigChain.ReadBillingInfo(teamPublicKey: teamIdentity.initialTeamPublicKey, token: nil)))
        
        let serverResponse:ServerResponse<SigChainBilling.BillingInfo> = server.sendSync(object: signedMessage.object, for: .billingInfo)

        switch serverResponse {
        case .error(let error):
            return .error(error)
            
        case .success(let billingInfo):
            return .result(billingInfo)
        }
    }
}
