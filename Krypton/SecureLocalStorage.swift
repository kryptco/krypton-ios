//
//  Caches.swift
//  Krypton
//
//  Created by Alex Grinman on 11/13/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class SecureLocalStorage {
    
    private static let rootDirectoryNameKey = "co.krypt.kryptonite.caches.key"

    enum Errors:Error {
        case noGroupDirectory
    }
    
    /// Use a random id as the caches root directory name, store the id in keychain
    private static func rootDirectory() throws -> URL {
        guard let groupDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupSecurityID) else {
            throw Errors.noGroupDirectory
        }
        
        var randomID:Data
        
        
        do {
            randomID = try KeychainStorage().getData(key: rootDirectoryNameKey)
        } catch KeychainStorageError.notFound {
            randomID = try Data.random(size: 32)
            try KeychainStorage().setData(key: rootDirectoryNameKey, data: randomID)
        }
        
        let rootDirectory = groupDirectory.appendingPathComponent(randomID.toBase64(true))
        return rootDirectory
    }
    
    /// Create the caches root directory marking it to not be backedup
    private static func createSecureLocalRootDirectory() throws -> URL {
        var rootDirectory = try SecureLocalStorage.rootDirectory()
        
        // create the directory if it doesn't exist
        try FileManager.default.createDirectory(at: rootDirectory,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
        
        // ensure caches are excluded
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try rootDirectory.setResourceValues(resourceValues)
        
        return rootDirectory
    }
    
    static func directory(for name:String) throws -> URL {
        let rootDirectory = try SecureLocalStorage.createSecureLocalRootDirectory()
        let directory = rootDirectory.appendingPathComponent(name)
        return directory
    }
    
  
}
