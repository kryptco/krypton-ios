//
//  Properties.swift
//  Krypton
//
//  Created by Alex Grinman on 10/5/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation

struct Properties {
    
    static let appName = "Krypton"
    
    static let defaultRemoteRequestAlert = "Krypton Request"
    static let defaultRemoteRequestAlertOld = "Kryptonite Request"

    //MARK: Version
    static let currentVersion = Version(major: 2, minor: 5, patch: 3)
    
    struct Compatibility {
        static let rsaSha256Sha512Support = Version(major: 2, minor: 1, patch: 0)
        static let appNameChange = Version(major: 2, minor: 3, patch: 1)

    }
    
    static let appVersionURL = "https://s3.amazonaws.com/kr-versions/versions"
    
    struct AppUpdateCheckInterval {
        static var foreground:TimeInterval {
            return TimeSeconds.hour.multiplied(by: 6)
        }
        
        static var background:TimeInterval {
            return TimeSeconds.week.rawValue
        }
    }

    //MARK: AWS
    static let awsAccessKey = "AKIAJMZJ3X6MHMXRF7QQ"
    static let awsSecretKey = "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"

    struct AWSPlatformARN {
        let sandbox:String
        let production:String
    }
    
    static let awsPlatformARN = AWSPlatformARN(
        sandbox: "arn:aws:sns:us-east-1:911777333295:app/APNS_SANDBOX/kryptco-ios-dev",
        production: "arn:aws:sns:us-east-1:911777333295:app/APNS/kryptco-ios-prod")
    
    static let awsQueueURLBase = "https://sqs.us-east-1.amazonaws.com/911777333295/"
    
    //MARK: Constants
    enum Interval:TimeInterval {
        //case fifteenSeconds = 15
        case oneHour = 3600
        case threeHours = 10800
    }

    //MARK: URLs

    static let contactUsEmail = "hello@krypt.co"
    static let openSourceURL = "https://krypt.co/app/open-source-libraries"
    static let privacyPolicyURL = "https://krypt.co/app/privacy"
    
    static let appStoreURL = "https://get.krypt.co"
    static let appURL = "https://krypt.co"
    
    static let transport = "https"
    
    //MARK: Teams
    static func teamsServerEndpoints() -> ServerEndpoints {
        if Platform.isDebug {
            return ServerEndpoints(apiHost: "api-dev.krypt.co",
                                   billingHost: "www-dev.krypt.co")
        } else {
            return ServerEndpoints(apiHost: "api.krypt.co",
                                   billingHost: "www.krypt.co")
        }

    }
    
    struct SigChainUpdateCheckInterval {
        static var foreground:TimeInterval {
            return TimeSeconds.hour.rawValue
        }
        
        static var background:TimeInterval {
            return TimeSeconds.hour.rawValue
        }
    }
    
    static func invitationText(for teamName:String) -> String {
        return  """
                You're invited to join \(teamName) on \(Properties.appName)!\n
                Step 1. Install: https://get.krypt.co
                Step 2. Accept Invite: tap the link below on your phone or copy this message (including the link) into \(Properties.appName).
                """
    }
    
    static func invitationHTML(for teamName:String, link:String) -> String? {
        guard let path = Bundle.main.path(forResource: "teams_invite_email_template", ofType: "html")
        else {
            return nil
        }

        do {
            var content = try String(contentsOfFile: path)
            content = content.replacingOccurrences(of: "TEAM_NAME", with: teamName)
            content = content.replacingOccurrences(of: "APP_NAME", with: Properties.appName)
            content = content.replacingOccurrences(of: "INVITE_LINK", with: link)
            
            return content
            
        } catch {
            return nil
        }

    }
    
    static func billingURL(for teamName:String, teamInitialPublicKey:Data, adminPublicKey:Data, adminEmail:String)-> String {
        let baseURL = "https://\(Properties.teamsServerEndpoints().billingHost)/billing/"
        
        let fullURL = "\(baseURL)?tn=\(teamName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? teamName)&tid=\(teamInitialPublicKey.toBase64(true))&aid=\(adminPublicKey.toBase64(true))&aem=\(adminEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? adminEmail)"
        return fullURL
    }
 
    //MARK: Analytics
    static var trackingID:String {
        if Platform.isDebug {
            return  "UA-86173430-1"
        }
        
        return "UA-86173430-2"
    }

    static let communicationActivityTimeout = 60.0
    static let allowedClockSkew = TimeSeconds.minute.multiplied(by: 15)
    static let requestTimeTolerance = allowedClockSkew
    
    //MARK: PGP Constant
    static let pgpMessageCommentOld = "Created with Kryptonite"
    static let defaultPGPMessageComment = "Created with \(Properties.appName)"
    
    static func pgpMessageComment(for version: Version) -> String {
        if version < Compatibility.appNameChange {
            return pgpMessageCommentOld
        }
        
        return defaultPGPMessageComment
    }

    init() {}
}
