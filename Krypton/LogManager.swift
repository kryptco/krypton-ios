//
//  PersistanceManager.swift
//  Krypton
//
//  Created by Alex Grinman on 9/13/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import CoreData
import JSON
import PGPFormat

class LogManager {
    
    private var mutex = Mutex()
    
    private static var sharedManagerMutex = Mutex()
    private static var sharedLogManager:LogManager?

    class var shared:LogManager {
        sharedManagerMutex.lock()
        defer { sharedManagerMutex.unlock() }
        
        guard let lm = sharedLogManager else {
            sharedLogManager = LogManager()
            return sharedLogManager!
        }
        return lm
    }
    
    //MARK: Core Data setup
    lazy var applicationDocumentsDirectory:URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupSecurityID)?.appendingPathComponent("logs")
    }()
    
    lazy var managedObjectModel:NSManagedObjectModel? = {
        guard let modelURL = Bundle.main.url(forResource:"Kryptonite", withExtension: "momd")
            else {
                return nil
        }
        
        return NSManagedObjectModel(contentsOf: modelURL)
    }()
    
    lazy var persistentStoreCoordinator:NSPersistentStoreCoordinator? = {
        guard
            let directoryURL = self.applicationDocumentsDirectory,
            let managedObjectModel = self.managedObjectModel
            else {
                return nil
        }
        
        // db file
        let url = directoryURL.appendingPathComponent("KryptoniteCoreDataStore.sqlite")
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        
        do {
            // create file if it doesn't exist
            if !FileManager.default.fileExists(atPath: directoryURL.absoluteString) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            let options = [NSMigratePersistentStoresAutomaticallyOption: true,
                           NSInferMappingModelAutomaticallyOption: true]

            let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
            store.didAdd(to: coordinator)
        } catch let e {
            log("Persistance store error: \(e)", .error)
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext:NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        
        return managedObjectContext
    }()

    
    // MARK: Fetching
    func fetch<L:LogStatement>(for session:String) -> [L] {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: L.entityName)
        fetchRequest.predicate = sessionEqualsPredicate(for: session)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        return fetchObjects(for: fetchRequest)
    }
    
    func fetchCompleteLatest(for session:String) -> LogStatement? {
        // find latest log
        var latestLogs:[LogStatement] = []
        
        if let sshLog:SSHSignatureLog = self.fetchLatest(for: session) {
            latestLogs.append(sshLog)
        }
        
        if let commitLog:CommitSignatureLog = self.fetchLatest(for: session) {
            latestLogs.append(commitLog)
        }
        
        if let tagLog:TagSignatureLog = self.fetchLatest(for: session) {
            latestLogs.append(tagLog)
        }
        
        return latestLogs.max(by: { $0.date < $1.date })
    }
    
    func fetchLatest<L:LogStatement>(for session:String) -> L? {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: L.entityName)
        fetchRequest.predicate = sessionEqualsPredicate(for: session)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        return fetchObjects(for: fetchRequest).first
    }
    

    private func sessionEqualsPredicate(for session:String) -> NSPredicate {
        return NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: "session"),
            rightExpression: NSExpression(forConstantValue: session),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
    }

    func fetchAll<L:LogStatement>() -> [L] {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: L.entityName)
        return fetchObjects(for: fetchRequest)
    }
    
    func fetchAllSSHUniqueHosts() -> [SSHSignatureLog] {
        defer { mutex.unlock() }
        mutex.lock()

        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: SSHSignatureLog.entityName)

        fetchRequest.propertiesToFetch = ["displayName"]
        fetchRequest.resultType = NSFetchRequestResultType.managedObjectIDResultType
        fetchRequest.returnsDistinctResults = true
        
        var logs:[SSHSignatureLog] = []

        self.managedObjectContext.performAndWait {
            do {
                let objectIds = try self.managedObjectContext.fetch(fetchRequest) as? [NSManagedObjectID]
                
                for objectId in (objectIds ?? []) {
                    
                    guard
                            let object = try? self.managedObjectContext.existingObject(with: objectId),
                            let log = try? SSHSignatureLog(object: object)
                    else {
                            continue
                    }
                    
                    logs.append(log)
                }
            } catch let error {
                log("could not fetch SSH logs: \(error)")
            }
        }

        
        return logs
    }
    
    private func fetchObjects<L:LogStatement>(for request:NSFetchRequest<NSFetchRequestResult>) -> [L] {
        defer { mutex.unlock() }
        mutex.lock()

        var logs:[L] = []
        
        self.managedObjectContext.performAndWait {
            do {
                let objects = try self.managedObjectContext.fetch(request) as? [NSManagedObject]
                
                for object in (objects ?? []) {
                    guard let log = try? L(object: object)
                    else {
                        continue
                    }
                    
                    logs.append(log)
                }
            } catch let error {
                log("could not fetch <\(L.entityName)> logs: \(error)")
            }
        }

        return logs
    }
    
    
    //MARK: Saving
    // backwards compatibility
    func save(auditLog:Audit.Log, sessionID:String) {
                
        switch auditLog.body {
        case .ssh(let sshSig):
            
            var signature:String
            
            switch sshSig.result {
            case .error(let error):
                signature = "error: \(error)"
            case .userRejected:
                signature = "rejected"
                
            case .hostMismatch:
                signature = "rejected"
                
            case .signature(let sig):
                signature = sig.toBase64()
            }
            
            let host = sshSig.hostAuthorization?.host ?? "unknown host"
            let display =  "\(sshSig.user) @ \(host)"
            
            let logStatement = SSHSignatureLog(session: sessionID, hostAuth: sshSig.hostAuthorization?.toHostAuth(), signature: signature, displayName:display)
            self.save(theLog: logStatement, deviceName: auditLog.session.deviceName)

        case .gitCommit(let commitSig):
            var signature:String
            var asciiArmoredSig:String?
            
            switch commitSig.result {
            case .error(let error):
                signature = "error: \(error)"
            case .userRejected:
                signature = "rejected"
                
            case .signature(let sig):
                signature = sig.toBase64()
                asciiArmoredSig = AsciiArmorMessage(packetData: sig, blockType: .signature, comment: Properties.defaultPGPMessageComment).toString()
            }
            
            var mergeParents:[GitHash]
            if commitSig.parents.count >= 2 {
                mergeParents = [GitHash](commitSig.parents[1 ..< commitSig.parents.count])
            } else {
                mergeParents = []
            }
            
            guard let commitInfo = try? CommitInfo(tree: commitSig.tree,
                                                 parent: commitSig.parents.first,
                                                 mergeParents: mergeParents,
                                                 author: commitSig.author,
                                                 committer: commitSig.committer,
                                                 message: commitSig.message)
            else {
                return
            }
            
            var commitHash:String
            if let asciiArmoredSig = asciiArmoredSig, let theCommitHash = try? commitInfo.commitHash(asciiArmoredSignature: asciiArmoredSig).hex {
                commitHash = theCommitHash
            } else {
                commitHash = ""
            }


            let logStatement = CommitSignatureLog(session: sessionID, signature: signature, commitHash: commitHash, commit: commitInfo)
            self.save(theLog: logStatement, deviceName: auditLog.session.deviceName)

        case .gitTag(let tagSig):
            var signature:String
            
            switch tagSig.result {
            case .error(let error):
                signature = "error: \(error)"
            case .userRejected:
                signature = "rejected"
                
            case .signature(let sig):
                signature = sig.toBase64()
            }
            
            
            guard let tagInfo = try? TagInfo(object: tagSig._object, type: tagSig.type, tag: tagSig.tag, tagger: tagSig.tagger, message: tagSig.message)
            else {
                return
            }
            
            let logStatement = TagSignatureLog(session: sessionID, signature: signature, tag: tagInfo)
            self.save(theLog: logStatement, deviceName: auditLog.session.deviceName)
        }
        
        
    }
    func save<L:LogStatement>(theLog:L, deviceName:String) {
        mutex.lock()
        
        log("saving \(theLog)")
        
        // update last log
        let defaults = UserDefaults.group
        defaults?.set(theLog.date.toShortTimeString(), forKey: "last_log_time")
        defaults?.set(theLog.displayName, forKey: "last_log_command")
        defaults?.set(deviceName, forKey: "last_log_device")
        defaults?.synchronize()
        
        
        self.managedObjectContext.performAndWait {
            
            guard let entity =  NSEntityDescription.entity(forEntityName: L.entityName, in: self.managedObjectContext)
            else {
                self.mutex.unlock()
                return
            }
            
            let logEntry = NSManagedObject(entity: entity, insertInto: self.managedObjectContext)
            
            // set attirbutes
            for (k,v) in theLog.managedObject {
                logEntry.setValue(v, forKey: k)
            }
            
            do {
                try self.managedObjectContext.save()
            } catch let error  {
                log("Could not save signature log: \(error)", .error)
            }
        }

        // unlock and notify we have a new log
        mutex.unlock()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "new_log"), object: nil)
    }
    

    
    //MARK: - Core Data Saving support
    func saveContext () {
        defer { mutex.unlock() }
        mutex.lock()

        managedObjectContext.performAndWait {
            if self.managedObjectContext.hasChanges {
                do {
                    try self.managedObjectContext.save()
                } catch {
                    log("Persistance manager save error: \(error)", .error)
                }
            }
        }
    }
}
