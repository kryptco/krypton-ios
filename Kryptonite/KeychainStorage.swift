//
//  KeychainStorage.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/1/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//
import Foundation
enum KeychainStorageError:Error {
    case notFound
    case saveError(OSStatus?)
    case update(OSStatus?)
    case delete(OSStatus?)
    case unknown(OSStatus?)
}
class KeychainStorage {

    var service:String
    var accessGroup:Bool

    var mutex = Mutex()

    init(service:String = Constants.defaultKeyChainService, accessGroup:Bool = false) {
        self.service = service
        self.accessGroup = accessGroup
    }

    func setData(key:String, data:Data) throws {
        mutex.lock()
        defer { self.mutex.unlock() }

        do {
            var params:[String:Any] = [String(kSecClass): kSecClassGenericPassword,
                                       String(kSecAttrService): service,
                                       String(kSecAttrAccount): key,
                                       String(kSecAttrAccessible): KeychainAccessiblity]

            if accessGroup {
                params[String(kSecAttrAccessGroup)] = Constants.keychainAccessGroup
            }

            let toUpdate:[String:Any] = [String(kSecValueData): data]

            let updateStatus = SecItemUpdate(params as CFDictionary,
                                             toUpdate as CFDictionary)
            
            // if key not found, need to add the entry
            if updateStatus == errSecItemNotFound {
                throw KeychainStorageError.notFound
            }
            
            guard updateStatus.isSuccess() else {
                throw KeychainStorageError.update(updateStatus)
            }
            
        } catch KeychainStorageError.notFound {

            var params:[String:Any] = [String(kSecClass): kSecClassGenericPassword,
                                       String(kSecAttrService): service,
                                       String(kSecAttrAccount): key,
                                       String(kSecValueData): data,
                                       String(kSecAttrAccessible): KeychainAccessiblity]

            if accessGroup {
                params[String(kSecAttrAccessGroup)] = Constants.keychainAccessGroup
            }
            let addStatus = SecItemAdd(params as CFDictionary, nil)
            guard  addStatus.isSuccess()
                else {
                    throw KeychainStorageError.saveError(addStatus)
            }
        }
    }

    func set(key:String, value:String) throws {
        try setData(key: key, data: value.utf8Data())
    }

    private func getDataUnlocked(key:String) throws -> Data {

        // if it exists then retrieve the item
        var params:[String:Any] = [String(kSecClass): kSecClassGenericPassword,
                                   String(kSecAttrService): service,
                                   String(kSecAttrAccount): key,
                                   String(kSecReturnData): kCFBooleanTrue,
                                   String(kSecAttrAccessible): KeychainAccessiblity]

        if accessGroup {
            params[String(kSecAttrAccessGroup)] = Constants.keychainAccessGroup
        }
        var object:AnyObject?
        let status = SecItemCopyMatching(params as CFDictionary, &object)

        if status == errSecItemNotFound {
            throw KeychainStorageError.notFound
        }

        guard let data = object as? Data, status.isSuccess() else {
            throw KeychainStorageError.unknown(status)
        }

        return data
    }

    func getData(key:String) throws -> Data {
        mutex.lock()
        defer { self.mutex.unlock() }

        return try self.getDataUnlocked(key: key)
    }

    func get(key:String) throws -> String {
        return try self.getData(key: key).utf8String()
    }

    func delete(key:String) throws {
        mutex.lock()
        defer { self.mutex.unlock() }

        var params:[String:Any] = [String(kSecClass): kSecClassGenericPassword,
                                   String(kSecAttrService): service,
                                   String(kSecAttrAccount): key,
                                   String(kSecAttrAccessible): KeychainAccessiblity]
        if accessGroup {
            params[String(kSecAttrAccessGroup)] = Constants.keychainAccessGroup
        }

        let status = SecItemDelete(params as CFDictionary)

        if status == errSecItemNotFound {
            throw KeychainStorageError.notFound
        }
        guard status.isSuccess() else {
            throw KeychainStorageError.delete(status)
        }
    }

}
