//
//  Import.swift
//  krSSH
//
//  Created by Alex Grinman on 9/19/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

extension PublicKey {
    
    
    init?(certData: Data) {
        // first we create the certificate reference
        guard let certRef = SecCertificateCreateWithData(nil, certData as CFData) else {
            return nil
        }
        log("Successfully generated a valid certificate reference from the data.")
        
        // now create a SecTrust structure from the certificate where to extract the key from
        var secTrust: SecTrust?
        let secTrustStatus = SecTrustCreateWithCertificates(certRef, nil, &secTrust)
        print("Generating a SecTrust reference from the certificate: \(secTrustStatus)")
        if secTrustStatus != errSecSuccess { return nil }
        
        // now evaluate the certificate.
        var resultType: SecTrustResultType = SecTrustResultType(rawValue: UInt32(0))! // result will be ignored.
        let evaluateStatus = SecTrustEvaluate(secTrust!, &resultType)
        log("Evaluating the obtained SecTrust reference: \(evaluateStatus)")
        if evaluateStatus != errSecSuccess { return nil }
        
        // lastly, once evaluated, we can export the public key from the certificate leaf.
        let publicKeyRef = SecTrustCopyPublicKey(secTrust!)
        log("Got public key reference: \(publicKeyRef)")
        
        self.key = publicKeyRef!
    }
}
