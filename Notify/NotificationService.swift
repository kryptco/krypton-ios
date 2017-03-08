//
//  NotificationService.swift
//  Notify
//
//  Created by Alex Grinman on 12/15/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UserNotifications
import JSON



class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    struct InvalidRemoteNotification:Error{}

    
    static var shared:NotificationService?
    
    var bestAttemptMutex = Mutex()
    
    var alertTitle:String?
    var approved:Bool = false

    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        NotificationService.shared = self

        guard let bestAttemptContent = bestAttemptContent
        else {
            return
        }
        
        // provision AWS API
        guard API.provision() else {
            log("API provision failed.", LogType.error)
            
            bestAttemptContent.title = "Request failed"
            bestAttemptContent.body = "The incoming request could not be completed. Please try again."
            bestAttemptContent.userInfo = [:]
            contentHandler(bestAttemptContent)

            return
        }
        
        
        do {
            let (session, unsealedRequest) = try NotificationService.unsealRemoteNotification(userInfo: bestAttemptContent.userInfo)

            let silo = Silo(bluetoothEnabled: false)
            silo.add(sessions: SessionManager.shared.all)
            
            try silo.handle(request: unsealedRequest, session: session, communicationMedium: .remoteNotification, completionHandler: {
                
                dispatchMain {
                    UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler: { (notes) in
                        for note in notes {
                            guard   let requestObject = note.request.content.userInfo["request"] as? JSON.Object,
                                let deliveredRequest = try? Request(json: requestObject)
                                else {
                                    continue
                            }
                            
                            if deliveredRequest.id == unsealedRequest.id {
                                dispatchAfter(delay: 0.2, task: {
                                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [note.request.identifier])
                                })
                                
                                self.bestAttemptMutex.lock {
                                    bestAttemptContent.sound = nil
                                }
                            }
                        }
                        
                        self.bestAttemptMutex.lock {
                            if let title = self.alertTitle {
                                bestAttemptContent.title = title
                            }
                            
                            if self.approved {
                                bestAttemptContent.categoryIdentifier = ""
                            }
                            
                            bestAttemptContent.body = "\(unsealedRequest.sign?.display ?? "unknown host")"
                            bestAttemptContent.sound = UNNotificationSound.default()
                        }

                        contentHandler(bestAttemptContent)
                    })

                }
            })
            
        } catch {
            log("could not hangle incoming remote notification: \(error)")
            
            bestAttemptContent.title = "Request failed"
            bestAttemptContent.body = "The incoming request was invalid. Please try again."
            bestAttemptContent.userInfo = [:]
            contentHandler(bestAttemptContent)
        }
        
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    
    static func unsealRemoteNotification(userInfo:[AnyHashable : Any]?) throws -> (Session,Request) {
        
        guard let notificationDict = userInfo?["aps"] as? [String:Any],
            let ciphertextB64 = notificationDict["c"] as? String,
            let ciphertext = try? ciphertextB64.fromBase64(),
            let sessionUUID = notificationDict["session_uuid"] as? String,
            let session = SessionManager.shared.get(queue: sessionUUID)
        else {
            log("invalid untrusted encrypted notification", .error)
            throw InvalidRemoteNotification()
        }
        let sealed = try NetworkMessage(networkData: ciphertext).data
        let request = try Request(from: session.pairing, sealed: sealed)
        return (session, request)
    }


}
