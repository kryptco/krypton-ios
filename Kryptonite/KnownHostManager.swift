//
//  KnownHostManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 4/27/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation


import CoreData
import JSON

struct HostMistmatchError:Error, CustomDebugStringConvertible {
    var hostName:String
    var expectedPublicKey:String
    
    static let prefix = "host public key mismatched for"
    
    var debugDescription:String {
        return "\(HostMistmatchError.prefix) \(hostName)"
    }
    
    // check if an error message is a host mismatch
    // used to indicate what kind of error occured to analytics
    // without exposing the hostName to the analytics service
    static func isMismatchErrorString(err:String) -> Bool {
        return err.contains(HostMistmatchError.prefix)
    }
}

struct HostAuthHasNoHostnames:Error, CustomDebugStringConvertible {
    var debugDescription:String {
        return "No hostnames provided"
    }
}


class KnownHostManager {
    
    private var mutex = Mutex()
    
    private static var sharedManagerMutex = Mutex()
    private static var sharedKnownHostManager:KnownHostManager?
    
    class var shared:KnownHostManager {
        sharedManagerMutex.lock()
        defer { sharedManagerMutex.unlock() }
        
        guard let hm = sharedKnownHostManager else {
            sharedKnownHostManager = KnownHostManager()
            return sharedKnownHostManager!
        }
        return hm
    }
    
    //MARK: Core Data setup
    lazy var applicationDocumentsDirectory:URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupSecurityID)?.appendingPathComponent("known_hosts")
    }()
    
    lazy var managedObjectModel:NSManagedObjectModel? = {
        guard let modelURL = Bundle.main.url(forResource:"KnownHosts", withExtension: "momd")
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
        let url = directoryURL.appendingPathComponent("KnownHostsDB.sqlite")
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
    
    
    /**
     Check if we have a public key verifiedHostAuth's hostName
     - if known host and does match: return true
     - if not known host or public key does not match: return false
     */
    func entryExists(for hostName:String) throws -> Bool {
        if let _ = try self.fetch(for: hostName) {
            return true
        }
        
        return false
    }
    
    /**
     
        Match verifiedHostAuth (hostName, publicKey to a known host:
            - if hostName not supplied: throw HostAuthHasNoHostnames
            - if hostName found and publicKey does match: do nothing
            - if hostName found and publicKey does NOT match: throw HostMistmatchError
            - if hostName does not exists: ping hostName <- publicKey and save it
     */
    func checkOrAdd(verifiedHostAuth:VerifiedHostAuth) throws {
        
        guard let hostName = verifiedHostAuth.hostName
        else {
            throw HostAuthHasNoHostnames()
        }
        
        let hostPublicKey = verifiedHostAuth.hostKey
        
        guard let existingKnownHost = try self.fetch(for: hostName)
        else {
            // known host doesn't exist
            // save it
            
            self.save(knownHost: KnownHost(hostName: hostName, publicKey: hostPublicKey))
            return
        }
        
        guard existingKnownHost.publicKey == hostPublicKey
        else {
            throw HostMistmatchError(hostName: hostName, expectedPublicKey: existingKnownHost.publicKey)
        }
    }
    
    // MARK: Fetching
    private func fetch(for hostName:String) throws -> KnownHost? {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "KnownHost")
        fetchRequest.predicate = hostNameEqualsPredicate(for: hostName)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_added", ascending: true)]
        fetchRequest.fetchLimit = 1

        return try fetchObjects(for: fetchRequest).first
    }
    
    private func hostNameEqualsPredicate(for hostName:String) -> NSPredicate {
        return NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: "host_name"),
            rightExpression: NSExpression(forConstantValue: hostName),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
    }
    
    func fetchAll() throws -> [KnownHost] {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "KnownHost")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_added", ascending: false)]
        return try fetchObjects(for: fetchRequest)
    }
    
    private func fetchObjects(for request:NSFetchRequest<NSFetchRequestResult>) throws -> [KnownHost] {
        defer { mutex.unlock() }
        mutex.lock()
        
        var knownHosts:[KnownHost] = []
        
        var caughtError:Error?
        self.managedObjectContext.performAndWait {
            do {
                let objects = try self.managedObjectContext.fetch(request) as? [NSManagedObject]
                
                for object in (objects ?? []) {
                    guard
                        let publicKey = object.value(forKey: "public_key") as? String,
                        let dateAdded = object.value(forKey: "date_added") as? Date,
                        let hostName = object.value(forKey: "host_name") as? String
                        else {
                            continue
                    }
                    
                    knownHosts.append(KnownHost(hostName: hostName, publicKey: publicKey, dateAdded: dateAdded))
                }

            } catch {
                caughtError = error
            }
        }
        
        if let error = caughtError {
            throw error
        }
        
        return knownHosts
    }
    
    //MARK: Delete entry
    
    func delete(_ knownHost:KnownHost) {
        defer { mutex.unlock() }
        mutex.lock()
        
        self.managedObjectContext.performAndWait {
            let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "KnownHost")
            fetchRequest.predicate = self.hostNameEqualsPredicate(for: knownHost.hostName)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_added", ascending: true)]
            fetchRequest.fetchLimit = 1
            
            guard   let object = ((try? self.managedObjectContext.fetch(fetchRequest)) as? [NSManagedObject])?.first,
                let publicKey = object.value(forKey: "public_key") as? String,
                let hostName = object.value(forKey: "host_name") as? String,
                hostName == knownHost.hostName,
                publicKey == knownHost.publicKey
                else {
                    return
            }
            
            self.managedObjectContext.delete(object)
            
            do {
                try self.managedObjectContext.save()
                
            } catch let error  {
                log("Could not save known host: \(error)", .error)
            }
        }

    }
    
    //MARK: Saving
    private func save(knownHost:KnownHost) {
        mutex.lock()
        
        self.managedObjectContext.performAndWait {
            guard
                let entity =  NSEntityDescription.entity(forEntityName: "KnownHost", in: self.managedObjectContext)
                else {
                    return
            }
            
            let hostEntry = NSManagedObject(entity: entity, insertInto: self.managedObjectContext)
            
            // set attirbutes
            hostEntry.setValue(knownHost.hostName, forKey: "host_name")
            hostEntry.setValue(knownHost.publicKey, forKey: "public_key")
            hostEntry.setValue(knownHost.dateAdded, forKey: "date_added")
            
            do {
                try self.managedObjectContext.save()
                
            } catch let error  {
                // if save failed, delete cached object
                self.managedObjectContext.delete(hostEntry)
                log("Could not save known host: \(error)", .error)
            }
        }
        
        mutex.unlock()
        
        // notify we have a new log
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "new_known_host"), object: nil)
    }
    
    
    
    //MARK: - Core Data Saving support
    func saveContext () {
        defer { mutex.unlock() }
        mutex.lock()
        
        self.managedObjectContext.performAndWait {
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
