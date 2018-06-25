//
//  U2FKeyManager.swift
//  Krypton
//
//  Created by Alex Grinman on 5/2/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

private let kryptonTagPrefix  = "co.krypt.u2f"

typealias U2FKeyTag = String

extension U2FAppID {
    var hash:U2FAppIDHash {
        return Data(bytes: [UInt8](self.utf8)).SHA256
    }
}

extension U2FKeyTag {
    /// key tag is: PREFIX + "." + H(key_handle)
    /// for H = SHA256
    init(keyHandle: U2FKeyHandle) {
        self = "\(kryptonTagPrefix).\(keyHandle.SHA256.toBase64(true))"
    }
}

class U2FDevice {
    private static let tag = "\(kryptonTagPrefix).device-identity"
    
    class func deviceIdentifier() throws -> U2FDeviceIdentifier {
        var keyPair:KeyPair
        
        if let existingKeyPair = try NISTP256KeyPair.load(tag) {
            keyPair = existingKeyPair
        } else {
            keyPair = try NISTP256KeyPair.generate(tag)
        }
        
        return try keyPair.publicKey.export().SHA256
    }
}

// random byte-array chosen to identify krypton devices
private let KryptonU2FKeyIdentifier:[UInt8] = [0x2c, 0xe5, 0xc8, 0xdf, 0x17, 0xe2, 0x2e, 0xf2,
                                               0x0f, 0xd3, 0x83, 0x03, 0xfd, 0x2d, 0x99, 0x98]

// KeyHandle: 80 bytes
// M + R + H(H(D) + H(R))
// where
// M = [16 Magic Bytes]
// R = [32 bytes of random]
// D = device_identifier
// H = SHA-256

extension U2FKeyHandle {
    static func new() throws -> U2FKeyHandle {
        var keyHandle = U2FKeyHandle()
        
        let random = try Data.random(size: 32)
        let privateDID = try (U2FDevice.deviceIdentifier().SHA256 + random.SHA256).SHA256

        // M
        keyHandle.append(Data(bytes: KryptonU2FKeyIdentifier))
        
        // R
        keyHandle.append(random)
        
        // H(H(D) + H(R))
        keyHandle.append(privateDID)
        
        return keyHandle
    }
}

class U2FKeyManager {
    
    enum Errors:Error {
        case keyNotFound
    }
    static let mutex = Mutex()

    /// Load a key pair for a service and key hanlde
    class func keyPair(for keyHandle: U2FKeyHandle) throws -> KeyPair {
        let tag = U2FKeyTag(keyHandle: keyHandle)
        
        guard let keyPair = try NISTP256KeyPair.load(tag) else {
            throw Errors.keyNotFound
        }
        
        return keyPair
    }
    
    /// Generate a key pair for a service
    /// returns the key pair along with a new keyhandle and attestation
    class func generate() throws -> (KeyPair, U2FKeyHandle) {
        let keyHandle = try U2FKeyHandle.new()
        let tag = U2FKeyTag(keyHandle: keyHandle)
        let keypair = try NISTP256KeyPair.generate(tag)
        
        return (keypair, keyHandle)
    }
    
    class func fetchAndIncrementCounter(keyHandle: U2FKeyHandle) throws -> Int32 {
        mutex.lock()
        defer { mutex.unlock() }
        
        let tag = "\(U2FKeyTag(keyHandle: keyHandle)).counter"
        
        var count:Int32
        
        do {
            guard let someCount = Int32(try KeychainStorage().get(key: tag)) else {
                throw KeychainStorageError.notFound
            }
            count = someCount
        } catch KeychainStorageError.notFound {
            count = 1
        } catch {
            throw error
        }
        
        try KeychainStorage().set(key: tag, value: "\(count + 1)")
        
        return count
    }
}

/// ASN.1 NISTP256 Public Key Encoding
private let Secp256r1Header:[UInt8] = [0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00]

extension PublicKey {
    func exportDerSecpData() throws -> Data {
        guard type == .nistP256 else {
            throw CryptoError.unsupportedMethodForKeyType
        }
        
        return try Data(bytes: Secp256r1Header) + self.export()
    }
    

    func toOpenSSL() throws -> UnsafeMutablePointer<EVP_PKEY> {
        var der = try self.exportDerSecpData()
        var derPointer:UnsafePointer<UInt8>? = der.withUnsafeBytes({ $0 })
        
        return try withUnsafeMutablePointer(to: &derPointer) {
            guard let validPubkey = d2i_PUBKEY(nil, $0, der.count) else {
                throw X509Error.initFailed
            }
            return validPubkey
        }
    }
}

extension Int32 {
    func okOr(_ error:X509Error) throws {
        guard self >= 0 else {
            throw error
        }
    }
}

class U2FSerialNumber {
    private static let serialNumberBase = "co.krypt.u2f.serial"
    
    class func serialNumberFor(publicKeyData: Data) -> Int {
        var preHash = Data(bytes: [UInt8](serialNumberBase.utf8)).SHA256
        preHash.append(publicKeyData.SHA256)
        
        var serialData = preHash.SHA256
        let bytesPointer:UnsafeMutablePointer<UInt8>? = serialData.withUnsafeMutableBytes({ $0 })
        
        return Int(bitPattern: bytesPointer)
    }
}

enum X509Error: Error {
    case initFailed
    case encoding
    case `extension`
    case publicKey
    case name
    case serial
    case signature
}

class U2FAttestationCertificate {
    
    private let x509: UnsafeMutablePointer<X509>
    
    init(x509: UnsafeMutablePointer<X509>) {
        self.x509 = x509
    }
    
    init(derEncoding: inout Data) throws {
        var bytesPointer:UnsafePointer<UInt8>? = derEncoding.withUnsafeBytes({ $0 })

        self.x509 = try withUnsafeMutablePointer(to: &bytesPointer, {
            let parsedCert = d2i_X509(nil, $0, derEncoding.count)
            guard let validCert = parsedCert else {
                throw X509Error.initFailed
            }
            return validCert
        })
    }

    func toDER() throws -> Data {
        var x509Bytes: UnsafeMutablePointer<UInt8>?
        let certLen = i2d_X509(x509, &x509Bytes)
        guard let unwrappedX509Bytes = x509Bytes, certLen >= 0 else {
            throw X509Error.encoding
        }
        return Data(bytes: unwrappedX509Bytes, count: Int(certLen))
    }

    deinit {
        X509_free(x509)
    }
}
