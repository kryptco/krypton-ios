//
//  AuthenticatedEncryption.swift
//  krSSH
//
//  Created by Alex Grinman on 9/3/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import CommonCrypto

extension Data {
    
    static func random(size:Int) throws -> Data {
        var result = [UInt8](repeating: 0, count: size)
        let res = SecRandomCopyBytes(kSecRandomDefault, size, &result)
        
        guard res == 0 else {
            throw CryptoError.random
        }
        
        return Data(bytes: result)
    }
    
    func HMAC(key:Data) throws -> Data {
        
        let keyBytes = key.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: key.count))
        }
        
        let dataBytes = self.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: self.count))
        }
        
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes, key.count, dataBytes, self.count, &hmac)
        
        return Data(bytes: hmac)
    }
    
    func seal(key:String) throws -> Data {
        let nonce = try Data.random(size: kCCBlockSizeAES128)
        let nonceBytes = nonce.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: nonce.count))
        }
        
        guard let keyData = key.fromBase64()
        else {
            throw CryptoError.encoding
        }
        
        let keyBytes = keyData.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: keyData.count))
        }
        var ciphertext = [UInt8](repeating: 0, count: self.count + 2*Int(kCCBlockSizeAES128))
        

        let dataBytes = self.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: self.count))
        }

        var ciphertextAllLength = 0
        
        let status = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES128), CCOptions(kCCOptionPKCS7Padding), keyBytes, keyData.count, nonceBytes, dataBytes, self.count, &ciphertext, ciphertext.count, &ciphertextAllLength)
        
        guard UInt32(status) == UInt32(kCCSuccess) else {
            throw CryptoError.encrypt
        }
        
        
        var nonceAndCiphertext = Data(capacity: nonce.count + ciphertext.count)
        nonceAndCiphertext.append(nonce)
        nonceAndCiphertext.append(Data(bytes: ciphertext).subdata(in: 0 ..< ciphertextAllLength))
        
        let hmac = try nonceAndCiphertext.HMAC(key: keyData)
        nonceAndCiphertext.append(hmac)
        
        return nonceAndCiphertext
    }
    
    func unseal(key:String) throws -> Data {
        guard
            let keyData = key.fromBase64(),
                count >= 2*Int(kCCBlockSizeAES128) + Int(CC_SHA256_DIGEST_LENGTH)
        else {
            throw CryptoError.encoding
        }
        
        let keyBytes = keyData.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: keyData.count))
        }

        let nonce = self.subdata(in: 0 ..< Int(kCCBlockSizeAES128))
        let nonceBytes = nonce.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: nonce.count))
        }
        
        let ciphertext = self.subdata(in: Int(kCCBlockSizeAES128) ..< count - Int(CC_SHA256_DIGEST_LENGTH))
        let ciphertextBytes = ciphertext.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: ciphertext.count))
        }
        
        let taggedHMAC = self.subdata(in: count - Int(CC_SHA256_DIGEST_LENGTH) ..< count)
        
        let hmac = try self.subdata(in: 0 ..< count - Int(CC_SHA256_DIGEST_LENGTH)).HMAC(key: keyData)
        
        // check HMAC
        guard taggedHMAC == hmac else {
            throw CryptoError.integrity
        }

        var plaintext = [UInt8](repeating: 0, count: ciphertext.count)
        var plaintextLength = 0
        
        let status = CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES128), CCOptions(kCCOptionPKCS7Padding), keyBytes, keyData.count, nonceBytes, ciphertextBytes, ciphertext.count, &plaintext, ciphertext.count, &plaintextLength)
        
        guard UInt32(status) == UInt32(kCCSuccess) else {
            throw CryptoError.decrypt
        }
        
        return Data(bytes: plaintext).subdata(in: 0 ..< plaintextLength)
    }
}
