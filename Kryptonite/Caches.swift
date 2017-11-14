//
//  Caches.swift
//  Kryptonite
//
//  Created by Alex Grinman on 11/13/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

class Caches {
    
    private static let cachesRootDirectoryName = "co.krypt.kryptonite.caches"
    
    enum Errors:Error {
        case noGroupDirectory
    }
    
    static func createCachesRootDirectory() throws {
        guard let groupDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_SECURITY_ID) else {
            throw Errors.noGroupDirectory
        }
        
        var cachesRootDirectory = groupDirectory.appendingPathComponent(cachesRootDirectoryName)
        
        // create the directory if it doesn't exist
        try FileManager.default.createDirectory(at: cachesRootDirectory,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
        
        // ensure caches are excluded
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try cachesRootDirectory.setResourceValues(resourceValues)
    }
    
    static func directory(for name:String) -> URL? {
        let groupDirectory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_SECURITY_ID)
        let cachesRootDirectory = groupDirectory?.appendingPathComponent(cachesRootDirectoryName)
        let cacheDirectory = cachesRootDirectory?.appendingPathComponent(name)
        
        return cacheDirectory
    }
    
    
}
