//
//  TeamDataManager.swift
//  Kryptonite
//
//  Created by Alex Grinman on 7/30/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import CoreData
import JSON

class TeamDataManager {
    
    private var mutex = Mutex()
    private let teamIdentity:String
    
    init(team:Team) {
        teamIdentity = "\(team.id)"
    }
    
    //MARK: Core Data setup
    lazy var applicationDocumentsDirectory:URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupSecurityID)?.appendingPathComponent("teams")
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
    
    func fetchAll() throws -> [Team.MemberIdentity] {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "Member")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_added", ascending: true)]
        
        return try fetchObjects(for: fetchRequest)
    }

    func fetchAll() throws -> [SSHHostKey] {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "SSHHostKey")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_added", ascending: true)]
        
        return try fetchObjects(for: fetchRequest)
    }
    
    
    /**
        Add a new block
     */
    func add(block:HashChain.Block) {
        self.save(block: block)
    }
    
    /**
        Add/remove member
     */
    func add(member:Team.MemberIdentity, blockHash:Data) {
        self.save(member: member, blockHash: blockHash)
    }
    
    func remove(member:SodiumPublicKey) {
        self.delete(memberPublicKey: member)
    }
    
    /**
        Pin/Unpin/check Known Hosts
     */
    func pin(sshHostKey:SSHHostKey, blockHash:Data) {
        self.save(sshHostKey: sshHostKey, blockHash: blockHash)
    }
    
    /** Match verifiedHostAuth (hostName, publicKey) to a pin (host, publickey)
        - returns true if host name is pinned and public key matches
        - returns false if host name is not pinned
        - throws HostMistmatchError if host name is pinned but public key is mismatched
    */
    func check(verifiedHost:VerifiedHostAuth) throws {
        
        guard let hostName = verifiedHost.hostName
        else {
            throw HostAuthHasNoHostnames()
        }
        
        let hostPublicKey = try verifiedHost.hostKey.fromBase64()
        
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "SSHHostKey")
        fetchRequest.predicate = self.sshHostNameOnlyEqualsPredicate(for: hostName)
        
        let sshHostKeys:[SSHHostKey] = try fetchObjects(for: fetchRequest)
        
        guard !sshHostKeys.isEmpty else {
            return
        }
        
        let matchingHosts = sshHostKeys.filter { $0.publicKey == hostPublicKey}
        
        guard false == matchingHosts.isEmpty
        else {
            let pinnedPublicKeysJoined = sshHostKeys.map({ $0.publicKey.toBase64() }).joined(separator: ",")
            throw HostMistmatchError(hostName: hostName, expectedPublicKey: pinnedPublicKeysJoined)
        }
    }
    
    /**
     Check if we have a public key verifiedHostAuth's hostName
     - if known host and does match: return true
     - if not known host or public key does not match: return false
     */
    func sshHostKeyExists(for hostName:String) throws -> Bool {
        
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "SSHHostKey")
        fetchRequest.predicate = self.sshHostNameOnlyEqualsPredicate(for: hostName)
        
        let sshHostKeys:[SSHHostKey] = try fetchObjects(for: fetchRequest)
        
        return sshHostKeys.isEmpty == false
    }



    func unpin(sshHostKey:SSHHostKey) {
        self.delete(sshHostKey: sshHostKey)
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
    
    private func fetchObjects(for request:NSFetchRequest<NSFetchRequestResult>) throws -> [Team.MemberIdentity] {
        defer { mutex.unlock() }
        mutex.lock()
        
        var members:[Team.MemberIdentity] = []
        
        var caughtError:Error?
        self.managedObjectContext.performAndWait {
            do {
                let objects = try self.managedObjectContext.fetch(request) as? [NSManagedObject]
                
                for object in (objects ?? []) {
                    guard
                        let email = object.value(forKey: "email") as? String,
                        let publicKey = object.value(forKey: "public_key") as? String,
                        let sshPublicKey = object.value(forKey: "ssh_public_key") as? String,
                        let pgpPublicKey = object.value(forKey: "pgp_public_key") as? String
                    else {
                        continue
                    }
                    
                    let member = try Team.MemberIdentity(publicKey: publicKey.fromBase64(),
                                                         email: email,
                                                         sshPublicKey: sshPublicKey.fromBase64(),
                                                         pgpPublicKey: pgpPublicKey.fromBase64())
                    members.append(member)
                }
                
            } catch {
                caughtError = error
            }
        }
        
        if let error = caughtError {
            throw error
        }
        
        return members
    }
    
    private func fetchObjects(for request:NSFetchRequest<NSFetchRequestResult>) throws -> [SSHHostKey] {
        defer { mutex.unlock() }
        mutex.lock()
        
        var hostKeys:[SSHHostKey] = []
        
        var caughtError:Error?
        self.managedObjectContext.performAndWait {
            do {
                let objects = try self.managedObjectContext.fetch(request) as? [NSManagedObject]
                
                for object in (objects ?? []) {
                    guard
                        let host = object.value(forKey: "host") as? String,
                        let publicKey = object.value(forKey: "public_key") as? String
                        else {
                            continue
                    }
                    
                    try hostKeys.append(SSHHostKey(host: host, publicKey: publicKey.fromBase64()))
                }
                
            } catch {
                caughtError = error
            }
        }
        
        if let error = caughtError {
            throw error
        }
        
        return hostKeys
    }


    
    
    //MARK: Saving
    private func save(member:Team.MemberIdentity, blockHash:Data) {
        mutex.lock()
        
        self.managedObjectContext.performAndWait {
            guard
                let entity =  NSEntityDescription.entity(forEntityName: "Member", in: self.managedObjectContext)
                else {
                    return
            }
            
            let hostEntry = NSManagedObject(entity: entity, insertInto: self.managedObjectContext)
            
            // set attirbutes
            hostEntry.setValue(member.email, forKey: "email")
            hostEntry.setValue(member.publicKey.toBase64(), forKey: "public_key")
            hostEntry.setValue(member.sshPublicKey.toBase64(), forKey: "ssh_public_key")
            hostEntry.setValue(member.pgpPublicKey.toBase64(), forKey: "pgp_public_key")
            hostEntry.setValue(blockHash.toBase64(), forKey: "block_hash")
            hostEntry.setValue(Date(), forKey: "date_added")
        }
        
        mutex.unlock()
        
        // notify we have a new log
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "new_block"), object: nil)
    }

    
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
        }
        
        mutex.unlock()
        
        // notify we have a new log
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "new_block"), object: nil)
    }
    
    private func save(sshHostKey:SSHHostKey, blockHash:Data) {
        mutex.lock()
        
        self.managedObjectContext.performAndWait {
            guard
                let entity =  NSEntityDescription.entity(forEntityName: "SSHHostKey", in: self.managedObjectContext)
                else {
                    return
            }
            
            let hostEntry = NSManagedObject(entity: entity, insertInto: self.managedObjectContext)
            
            // set attirbutes
            hostEntry.setValue(sshHostKey.host, forKey: "host")
            hostEntry.setValue(sshHostKey.publicKey.toBase64(), forKey: "public_key")
            hostEntry.setValue(blockHash.toBase64(), forKey: "block_hash")
            hostEntry.setValue(Date(), forKey: "date_added")
        }
        
        mutex.unlock()
        
        // notify we have a new log
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "new_block"), object: nil)
    }

    
    //MARK: Deleting
    
    private func delete(memberPublicKey:SodiumPublicKey) {
        defer { mutex.unlock() }
        mutex.lock()
        
        self.managedObjectContext.performAndWait {
            let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "Member")
            fetchRequest.predicate = self.memberEqualsPredicate(for: memberPublicKey)
            
            guard  let objects = (try? self.managedObjectContext.fetch(fetchRequest)) as? [NSManagedObject]
            else {
                return
            }
            
            objects.forEach {
                self.managedObjectContext.delete($0)
            }
        }
    }

    private func memberEqualsPredicate(for memberPublicKey:SodiumPublicKey) -> NSPredicate {
        return NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: "public_key"),
            rightExpression: NSExpression(forConstantValue: memberPublicKey.toBase64()),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )
    }
    
    
    private func delete(sshHostKey:SSHHostKey) {
        defer { mutex.unlock() }
        mutex.lock()
        
        self.managedObjectContext.performAndWait {
            let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "SSHHostKey")
            fetchRequest.predicate = self.sshHostNameAndKeyEqualsPredicate(for: sshHostKey)
            
            guard  let objects = (try? self.managedObjectContext.fetch(fetchRequest)) as? [NSManagedObject]
                else {
                    return
            }
            
            objects.forEach {
                self.managedObjectContext.delete($0)
            }
        }
    }
    
    private func sshHostNameOnlyEqualsPredicate(for host:String) -> NSPredicate {
        let hostPredicate =  NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: "host"),
            rightExpression: NSExpression(forConstantValue: host),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )

        return hostPredicate
    }
    
    private func sshHostNameAndKeyEqualsPredicate(for sshHostKey:SSHHostKey) -> NSPredicate {
        
        let hostPredicate = sshHostNameOnlyEqualsPredicate(for: sshHostKey.host)
        
        let pubKeyPredicate =  NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: "public_key"),
            rightExpression: NSExpression(forConstantValue: sshHostKey.publicKey.toBase64()),
            modifier: .direct,
            type: .equalTo,
            options: NSComparisonPredicate.Options(rawValue: 0)
        )

        return NSCompoundPredicate(andPredicateWithSubpredicates: [hostPredicate, pubKeyPredicate])
    }


    
    //MARK: - Core Data Saving/Roll back support
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
    
    func rollbackContext () {
        defer { mutex.unlock() }
        mutex.lock()
        
        self.managedObjectContext.performAndWait {
            if self.managedObjectContext.hasChanges {
                self.managedObjectContext.rollback()
            }
        }
    }
}
