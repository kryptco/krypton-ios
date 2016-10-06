//
//  Properties.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/5/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation

class Properties {
    
    //MARK: Singelton
    private static var sharedProperties:Properties?
    
    class var shared:Properties {
        guard let sp = sharedProperties else {
            sharedProperties = Properties()
            return sharedProperties!
        }
        return sp
    }
    
    
    //MARK: URLs
    // private static let remotePropertiesURL = "krypt.co/app/properties.json"
    // private static let localPropertiesURL = "properties.json"

    
    //MARK: Properties
    let requestKeyURLBase = "kr://import?r="
    
    let awsAccessKey = "AKIAJMZJ3X6MHMXRF7QQ"
    let awsSecretKey = "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"

    struct AWSPlatformARN {
        let sandbox:String
        let production:String
    }
    
    let awsPlatformARN = AWSPlatformARN(
        sandbox: "arn:aws:sns:us-east-1:911777333295:app/APNS_SANDBOX/kryptco-ios-dev",
        production: "arn:aws:sns:us-east-1:911777333295:app/APNS/kryptco-ios-prod")
    

    let awsQueueURLBase = "https://sqs.us-east-1.amazonaws.com/911777333295/"
    
    let contactUsEmail = "hello@krypt.co"
    let openSourceURL = "https://krypt.co/app/open-source"
    let privacyPolicyURL = "https://krypt.co/app/privacy"

    init() {
        
    }
    
    
}
