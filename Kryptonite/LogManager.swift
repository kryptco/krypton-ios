//
//  PersistanceManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/13/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import CoreData
import JSON

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
        let url = directoryURL.appendingPathComponent("KryptoniteCoreDataStore.sqlite")
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

    
    // MARK: Fetching
    func fetch(for session:String) -> [SignatureLog] {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "SignatureLog")
        fetchRequest.predicate = NSPredicate(format: "session = '\(session)'")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        return fetchObjects(for: fetchRequest)
    }
    
    func fetchLatest(for session:String) -> SignatureLog? {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "SignatureLog")
        fetchRequest.predicate = NSPredicate(format: "session = '\(session)'")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        return fetchObjects(for: fetchRequest).first
    }

    func fetchAll() -> [SignatureLog] {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "SignatureLog")
        return fetchObjects(for: fetchRequest)
    }
    
    private func fetchObjects(for request:NSFetchRequest<NSFetchRequestResult>) -> [SignatureLog] {
        defer { mutex.unlock() }
        mutex.lock()

        var logs:[SignatureLog] = []
        
        do {
            let objects = try self.managedObjectContext.fetch(request) as? [NSManagedObject]
            
            for object in (objects ?? []) {
                guard
                    let session = object.value(forKey: "session") as? String,
                    let signature = object.value(forKey: "signature") as? String,
                    let date = object.value(forKey: "date") as? Date,
                    let hostAuth = object.value(forKey: "host_auth") as? String,
                    let displayName = object.value(forKey: "displayName") as? String
                    else {
                        continue
                }
                
                logs.append(SignatureLog(session: session, hostAuth: hostAuth, signature: signature, displayName: displayName, date: date))
            }
        } catch {
            log("could not fetch signature logs: \(error)")
        }
    

        return logs
    }
    
    
    //MARK: Saving
    func save(theLog:SignatureLog, deviceName:String) {
        defer { mutex.unlock() }
        mutex.lock()
        
        log("saving \(theLog)")
        
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
        logEntry.setValue(theLog.date, forKey: "date")
        logEntry.setValue(theLog.hostAuth, forKey: "host_auth")
        logEntry.setValue(theLog.displayName, forKey: "displayName")
        
        //
        do {
            try self.managedObjectContext.save()
            
        } catch let error  {
            log("Could not save signature log: \(error)", .error)
        }
        
        // notify we have a new log
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "new_log"), object: nil)
    }
    

    
    //MARK: - Core Data Saving support
    func saveContext () {
        defer { mutex.unlock() }
        mutex.lock()
        
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                log("Persistance manager save error: \(error)", .error)

            }
        }
    }
}
