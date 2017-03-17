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
    
    struct InvalidRemoteNotification:Error{}

    var bestAttemptMutex = Mutex()
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        
        self.contentHandler = contentHandler
        
        // provision AWS API
        guard API.provision() else {
            log("API provision failed.", LogType.error)
            
            failUnknown(with: nil)
            
            return
        }
        
        var session:Session
        var unsealedRequest:Request
        do {
            (session, unsealedRequest) = try NotificationService.unsealRemoteNotification(userInfo: request.content.userInfo)

        } catch {
            log("could not processess remote notification content: \(error)")
            
            failUnknown(with: error)

            return
        }
        
        
        do {

            let silo = Silo(bluetoothEnabled: false)
            silo.add(sessions: SessionManager.shared.all)
            
            try silo.handle(request: unsealedRequest, session: session, communicationMedium: .remoteNotification, completionHandler: {
                
                dispatchMain {
                    UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler: { (notes) in
                        
                        var noSound = false
                        
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
                                
                                noSound = true
                                break
                            }
                        }
                        
                        self.bestAttemptMutex.lock {
                            
                            let content = UNMutableNotificationContent()
                            
                            // approved
                            if silo.hasCachedResponse(for: unsealedRequest) {
                                content.title = "Approved request from \(session.pairing.displayName)."
                                content.categoryIdentifier = ""
                            }
                            // not approved
                            else {
                                content.title = "Request from \(session.pairing.displayName)."
                            }
                            
                            content.body = "\(unsealedRequest.sign?.display ?? "unknown host")"
                            content.userInfo = ["session_id": session.id, "request": unsealedRequest.object]
                            
                            if noSound {
                                content.sound = nil
                            } else {
                                content.sound = UNNotificationSound.default()
                            }
                            
                            contentHandler(content)

                        }

                    })

                }
            })
            
        } catch {
            
            UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler: { (notes) in
                for note in notes {
                    if note.request.identifier == unsealedRequest.id {
                        
                        let noteContent = note.request.content

                        self.bestAttemptMutex.lock {
                            let currentContent = UNMutableNotificationContent()
                            currentContent.title = noteContent.title
                            currentContent.categoryIdentifier = noteContent.categoryIdentifier
                            currentContent.body = "\(unsealedRequest.sign?.display ?? "unknown host")"
                            currentContent.userInfo = noteContent.userInfo
                            currentContent.sound = UNNotificationSound.default()
                            
                            contentHandler(currentContent)
                        }
                        // remove old note
                        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [note.request.identifier])
                        
                        // replace with remote with same content
                        
                        return
                    }
                }
                
                self.failUnknown(with: error)
            })
        }
        
    }
    
    func failUnknown(with error:Error?) {
        
        let content = UNMutableNotificationContent()

        content.title = "Request failed"
        if let e = error {
            content.body = "The incoming request was invalid. \(e). Please try again."
        } else {
            content.body = "The incoming request was invalid. Please try again."
        }
        content.userInfo = [:]
        
        contentHandler?(content)
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        
        let content = UNMutableNotificationContent()
        
        content.title = "Request could not be completed"
        content.body = "The incoming request timed out. Please try again."
        
        contentHandler?(content)
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
