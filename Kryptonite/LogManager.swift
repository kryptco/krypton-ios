//
//  PersistanceManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/13/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import CoreData

class LogManager {
    
    private var mutex = Mutex()
    private var logs:[SignatureLog] = []
    private var sigs:[String:Bool] = [:]
    
    
    private static var sharedManagerMutex = Mutex()
    private static var sharedLogManager:LogManager?


    init() {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "SignatureLog")
        
        do {
            let results =
                try self.managedObjectContext.fetch(fetchRequest) as? [NSManagedObject]
            
            for managedLog in (results ?? []) {
                guard
                    let session = managedLog.value(forKey: "session") as? String,
                    let digest = managedLog.value(forKey: "digest") as? String,
                    let signature = managedLog.value(forKey: "signature") as? String,
                    let date = managedLog.value(forKey: "date") as? Date,
                    let displayName = managedLog.value(forKey: "displayName") as? String
                else {
                    continue
                }
                
                if sigs[digest] == nil {
                    logs.append(SignatureLog(session: session, digest: digest, signature: signature, displayName: displayName, date: date))
                    sigs[digest] = true
                }
                
            }
            
        } catch {
            log("could not fetch signature logs: \(error)")
        }

    }
    
    class var shared:LogManager {
        sharedManagerMutex.lock()
        defer { sharedManagerMutex.unlock() }
        
        guard let lm = sharedLogManager else {
            sharedLogManager = LogManager()
            return sharedLogManager!
        }
        return lm
    }
    
    var all:[SignatureLog] {
        var theLogs:[SignatureLog] = []
        mutex.lock {
            theLogs = [SignatureLog](self.logs).filter({ $0.signature != "rejected" })
        }
        return theLogs
    }
    
    func save(theLog:SignatureLog, deviceName:String) {
        mutex.lock()

        log("saving \(theLog)")
        
        guard sigs[theLog.digest] == nil else {
            mutex.unlock()
            return
        }
        
        sigs[theLog.digest] = true
        
        mutex.unlock()
        
        // update last log
        let defaults = UserDefaults.group
        defaults?.set(theLog.date.toShortTimeString(), forKey: "last_log_time")
        defaults?.set(theLog.displayName, forKey: "last_log_command")
        defaults?.set(deviceName, forKey: "last_log_device")
        defaults?.synchronize()
        //
        
        guard
            let entity =  NSEntityDescription.entity(forEntityName: "SignatureLog", in: managedObjectContext)
        else {
            return
        }
        
        let logEntry = NSManagedObject(entity: entity, insertInto: managedObjectContext)
        
        // set attirbutes
        logEntry.setValue(theLog.session, forKey: "session")
        logEntry.setValue(theLog.signature, forKey: "signature")
        logEntry.setValue(theLog.digest, forKey: "digest")
        logEntry.setValue(theLog.date, forKey: "date")
        logEntry.setValue(theLog.displayName, forKey: "displayName")
        
        //
        do {
            try self.managedObjectContext.save()
            
            mutex.lock {
                logs.append(theLog)
            }
            
        } catch let error  {
            log("Could not save signature log: \(error)", .error)
        }
        
        // notify we have a new log
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "new_log"), object: nil)

    }
    
    lazy var applicationDocumentsDirectory:URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_SECURITY_ID)?.appendingPathComponent("logs")
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
        let url = directoryURL.appendingPathComponent("KryptoniteCoreData.sqlite")
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

        do {
            // create file if it doesn't exist
            if !FileManager.default.fileExists(atPath: directoryURL.absoluteString) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            }

            let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
            store.didAdd(to: coordinator)
        } catch let e {
            log("Persistance store error: \(e)", .error)
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext:NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    
    
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                log("Persistance manager save error: \(error)", .error)

            }
        }
    }

}

extension Session {
    var lastAccessed:Date? {
        return LogManager.shared.all.filter({ $0.session == self.id }).sorted(by: { $0.date < $1.date }).last?.date
    }
}
