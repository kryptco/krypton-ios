//
//  HashChainManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import CoreData
import JSON

class HashChainBlockManager {
    
    private var mutex = Mutex()
    private let teamIdentity:String
    
    init(team:Team) {
        teamIdentity = "\(team.id)_\(team.publicKey.toBase64(true))"
    }
    
    //MARK: Core Data setup
    lazy var applicationDocumentsDirectory:URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_SECURITY_ID)?.appendingPathComponent("teams")
    }()
    
    lazy var managedObjectModel:NSManagedObjectModel? = {
        guard let modelURL = Bundle.main.url(forResource:"Teams", withExtension: "momd")
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
        let url = directoryURL.appendingPathComponent("db_\(self.teamIdentity).sqlite")
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
        Check if a block exists, and if it does retrieve it
     */
    func fetchBlock(hash:String) throws -> HashChain.Block? {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "Block")
        fetchRequest.predicate = blockHashEqualsPredicate(for: hash)
        fetchRequest.fetchLimit = 1
        
        return try fetchObjects(for: fetchRequest).first
    }
    
    private func blockHashEqualsPredicate(for blockHash:String) -> NSPredicate {
        return NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: "block_hash"),
            rightExpression: NSExpression(forConstantValue: blockHash),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
    }
    
    /**
        fetch all blocks sorted by date
     */
    
    func fetchAll() throws -> [HashChain.Block] {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "Block")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_added", ascending: false)]
        
        return try fetchObjects(for: fetchRequest)
    }

    
    /**
        Add a new block
     */
    func add(block:HashChain.Block) throws {
        self.save(block: block)
    }
    
    
    private func fetchObjects(for request:NSFetchRequest<NSFetchRequestResult>) throws -> [HashChain.Block] {
        defer { mutex.unlock() }
        mutex.lock()
        
        var blocks:[HashChain.Block] = []
        
        var caughtError:Error?
        self.managedObjectContext.performAndWait {
            do {
                let objects = try self.managedObjectContext.fetch(request) as? [NSManagedObject]
                
                for object in (objects ?? []) {
                    guard
                        let payload = object.value(forKey: "payload") as? String,
                        let signature = object.value(forKey: "signature") as? String,
                        let signatureData = try? signature.fromBase64()
                    else {
                            continue
                    }
                    
                    blocks.append(HashChain.Block(payload: payload, signature: signatureData))
                }
                
            } catch {
                caughtError = error
            }
        }
        
        if let error = caughtError {
            throw error
        }
        
        return blocks
    }
    
    
    //MARK: Saving
    private func save(block:HashChain.Block) {
        mutex.lock()
        
        self.managedObjectContext.performAndWait {
            guard
                let entity =  NSEntityDescription.entity(forEntityName: "Block", in: self.managedObjectContext)
                else {
                    return
            }
            
            let hostEntry = NSManagedObject(entity: entity, insertInto: self.managedObjectContext)
            
            // set attirbutes
            hostEntry.setValue(block.payload, forKey: "payload")
            hostEntry.setValue(block.signature.toBase64(), forKey: "signature")
            hostEntry.setValue(block.hash().toBase64(), forKey: "block_hash")
            hostEntry.setValue(Date(), forKey: "date_added")

            do {
                try self.managedObjectContext.save()
                
            } catch let error  {
                // if save failed, delete cached object
                self.managedObjectContext.delete(hostEntry)
                log("Could not save block: \(error)", .error)
            }
        }
        
        mutex.unlock()
        
        // notify we have a new log
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "new_block"), object: nil)
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
