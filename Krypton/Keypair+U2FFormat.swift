//
//  Keypair+U2FFormat.swift
//  Krypton
//
//  Created by Alex Grinman on 5/2/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import CommonCrypto

private let kryptonCommonName = "Krypton Key"

extension KeyPair {
    
    /**
        Create a self-signed attestion certificate
     */
    func signU2FAttestationCertificate(commonName:String = kryptonCommonName, daysValidFor: Int = 365*10) throws -> U2FAttestationCertificate {
        
        guard let x509 = X509_new() else {
            throw X509Error.initFailed
        }
        
        let name = X509_NAME_new()
        X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_FLAG|1, commonName, Int32(commonName.utf8.count), -1, 0)
        
        try X509_set_issuer_name(x509, name).okOr(.name)
        try X509_set_subject_name(x509, name).okOr(.name)
        
        let pubkey = try self.publicKey.toOpenSSL()
        try X509_set_pubkey(x509, pubkey).okOr(.publicKey)
        
        try ASN1_INTEGER_set(X509_get_serialNumber(x509), U2FSerialNumber.serialNumberFor(publicKeyData: self.publicKey.export())).okOr(.serial)
        
        X509_gmtime_adj(x509.pointee.cert_info.pointee.validity.pointee.notBefore, 0)
        X509_gmtime_adj(x509.pointee.cert_info.pointee.validity.pointee.notAfter, daysValidFor*86400)
        
        try "CA:FALSE".withCString { strPtr -> Int32 in
            let ext = X509V3_EXT_conf_nid(nil, nil, NID_basic_constraints, UnsafeMutablePointer<CChar>(mutating: strPtr))
            let result = X509_add_ext(x509, ext, -1)
            X509_EXTENSION_free(ext)
            
            return result
            }.okOr(.extension)
        
        X509_set_version(x509, 2)
        
        let sigPtr : UnsafeMutablePointer<X509_ALGOR>? = x509.pointee.cert_info.pointee.signature
        let sigAlgPtr : UnsafeMutablePointer<X509_ALGOR>? = x509.pointee.sig_alg
        
        X509_ALGOR_set0(sigPtr, OBJ_nid2obj(NID_ecdsa_with_SHA256), V_ASN1_UNDEF, nil)
        X509_ALGOR_set0(sigAlgPtr, OBJ_nid2obj(NID_ecdsa_with_SHA256), V_ASN1_UNDEF, nil)
        
        var toSignBuf : UnsafeMutablePointer<UInt8>?
        let inputLen =  ASN1_item_i2d(OpaquePointer(x509.pointee.cert_info), &toSignBuf, X509_CINF_RPTR())
        
        guard let toSignBytes = toSignBuf else {
            throw X509Error.encoding
        }
        
        let toSign = Data(bytes: toSignBytes, count: Int(inputLen))
        
        // set the signature
        var signature = try self.sign(data: toSign, digestType: .sha256)
        let signatureBytes:UnsafeMutablePointer<UInt8> = signature.withUnsafeMutableBytes({$0})
        try ASN1_BIT_STRING_set(x509.pointee.signature, signatureBytes, Int32(signature.count)).okOr(.signature)
        
        // Source: openssl/crypto/asn1/a_sign.c
        x509.pointee.signature.pointee.flags = Int((Int32(~(ASN1_STRING_FLAG_BITS_LEFT | 0x07)) & Int32(x509.pointee.signature.pointee.flags)) | ASN1_STRING_FLAG_BITS_LEFT)
        
        return U2FAttestationCertificate(x509: x509)
    }

    /**
        Returns a signature of the U2F protocol registration payload
     */
    func signU2FRegistration(application: U2FAppIDHash, keyHandle:U2FKeyHandle, challenge: Data) throws -> Data {
        let publicKeyDER = try self.publicKey.export()
        
        var toSign = Data()
        toSign.append(0x00)
        toSign.append(application)
        toSign.append(challenge)
        toSign.append(keyHandle)
        toSign.append(publicKeyDER)
        
        return try self.sign(data: toSign, digestType: .sha256)
    }
    
    /**
        Returns a signature of the U2F protocol authentication payload
     */
    func signU2FAuthentication(application: U2FAppIDHash, counter: Int32, challenge:Data) throws -> Data {
        var toSign = Data()
        toSign.append(application)
        toSign.append(0x01)
        toSign.append(UInt8((counter >> 24) & 0xff))
        toSign.append(UInt8((counter >> 16) & 0xff))
        toSign.append(UInt8((counter >> 8) & 0xff))
        toSign.append(UInt8((counter >> 0) & 0xff))
        toSign.append(challenge)
        
        return try self.sign(data: toSign, digestType: .sha256)
    }

}
