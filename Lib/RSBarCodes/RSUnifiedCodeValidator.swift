//
//  RSUnifiedCodeValidator.swift
//  RSBarcodesSample
//
//  Created by R0CKSTAR on 10/3/16.
//  Copyright (c) 2016 P.D.Q. All rights reserved.
//

import Foundation
import AVFoundation

public class RSUnifiedCodeValidator {
    public class var shared: RSUnifiedCodeValidator {
        return UnifiedCodeValidatorSharedInstance
    }
    
    public func isValid(_ contents:String, machineReadableCodeObjectType: String) -> Bool {
        var codeGenerator: RSCodeGenerator?
        
        // RS types
        switch machineReadableCodeObjectType {
        case RSBarcodesTypeISBN13Code:
            codeGenerator = RSISBN13Generator()
        case RSBarcodesTypeISSN13Code:
            codeGenerator = RSISSN13Generator()
        case RSBarcodesTypeExtendedCode39Code:
            codeGenerator = RSExtendedCode39Generator()
        default:
            break
        }
        
        if codeGenerator != nil {
            return codeGenerator!.isValid(contents)
        }
        
        // otherwise parse system types
        let objectType = AVMetadataObject.ObjectType(rawValue: machineReadableCodeObjectType)
        
        switch objectType {
        case .qr, .pdf417, .aztec:
            return false
        case .code39:
            codeGenerator = RSCode39Generator()
        case .code39Mod43:
            codeGenerator = RSCode39Mod43Generator()
        case .ean8:
            codeGenerator = RSEAN8Generator()
        case .ean13:
            codeGenerator = RSEAN13Generator()
        case .interleaved2of5:
            codeGenerator = RSITFGenerator()
        case .itf14:
            codeGenerator = RSITF14Generator()
        case .upce:
            codeGenerator = RSUPCEGenerator()
        case .code93:
            codeGenerator = RSCode93Generator()
        case .code128:
            codeGenerator = RSCode128Generator()
        case .dataMatrix:
            codeGenerator = RSCodeDataMatrixGenerator()
        default:
            print("No code generator selected.")
            return false
        }
        return codeGenerator!.isValid(contents)
    }
}
let UnifiedCodeValidatorSharedInstance = RSUnifiedCodeValidator()
