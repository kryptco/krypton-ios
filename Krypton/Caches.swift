//
//  Caches.swift
//  Krypton
//
//  Created by Alex Grinman on 11/13/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class Caches {
    
    private static let cachesRootDirectoryNameKey = "co.krypt.kryptonite.caches.key"

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
            randomID = try KeychainStorage().getData(key: cachesRootDirectoryNameKey)
        } catch KeychainStorageError.notFound {
            randomID = try Data.random(size: 32)
            try KeychainStorage().setData(key: cachesRootDirectoryNameKey, data: randomID)
        }
        
        let cachesRootDirectory = groupDirectory.appendingPathComponent(randomID.toBase64(true))
        return cachesRootDirectory

    }
    
    /// Create the caches root directory marking it to not be backedup
    private static func createCachesRootDirectory() throws -> URL {
        var cachesRootDirectory = try Caches.rootDirectory()
        
        // create the directory if it doesn't exist
        try FileManager.default.createDirectory(at: cachesRootDirectory,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
        
        // ensure caches are excluded
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try cachesRootDirectory.setResourceValues(resourceValues)
        
        return cachesRootDirectory
    }
    
    static func directory(for name:String) throws -> URL {
        let cachesRootDirectory = try Caches.createCachesRootDirectory()
        let cacheDirectory = cachesRootDirectory.appendingPathComponent(name)
        return cacheDirectory
    }
    
  
}
