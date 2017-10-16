//
//  RSUnifiedCodeGenerator.swift
//  RSBarcodesSample
//
//  Created by R0CKSTAR on 6/10/14.
//  Copyright (c) 2014 P.D.Q. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

public class RSUnifiedCodeGenerator: RSCodeGenerator {
    
    public var isBuiltInCode128GeneratorSelected = false
    public var fillColor: UIColor = UIColor.white
    public var strokeColor: UIColor = UIColor.black
    
    public class var shared: RSUnifiedCodeGenerator {
        return UnifiedCodeGeneratorSharedInstance
    }
    
    // MARK: RSCodeGenerator
    
    public func isValid(_ contents: String) -> Bool {
        print("Use RSUnifiedCodeValidator.shared.isValid(contents:String, machineReadableCodeObjectType: String) instead")
        return false
    }
    
    public func generateCode(_ contents: String, inputCorrectionLevel: InputCorrectionLevel, machineReadableCodeObjectType: String) -> UIImage? {
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
        
        if codeGenerator == nil {
            // otherwise parse system types
            let objectType = AVMetadataObject.ObjectType(rawValue: machineReadableCodeObjectType)
            
            switch objectType {
            case .qr, .pdf417, .aztec:
                return RSAbstractCodeGenerator.generateCode(contents, inputCorrectionLevel: inputCorrectionLevel, filterName: RSAbstractCodeGenerator.filterName(machineReadableCodeObjectType))
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
                if self.isBuiltInCode128GeneratorSelected {
                    return RSAbstractCodeGenerator.generateCode(contents, inputCorrectionLevel: inputCorrectionLevel, filterName: RSAbstractCodeGenerator.filterName(machineReadableCodeObjectType))
                } else {
                    codeGenerator = RSCode128Generator()
                }
            case .dataMatrix:
                codeGenerator = RSCodeDataMatrixGenerator()
            default:
                break
            }
        }
        
        if codeGenerator != nil {
            codeGenerator!.fillColor = self.fillColor
            codeGenerator!.strokeColor = self.strokeColor
            return codeGenerator!.generateCode(contents, inputCorrectionLevel: inputCorrectionLevel, machineReadableCodeObjectType: machineReadableCodeObjectType)
        } else {
            return nil
        }
    }
    
    public func generateCode(_ contents: String, machineReadableCodeObjectType: String) -> UIImage? {
        return self.generateCode(contents, inputCorrectionLevel: .Medium, machineReadableCodeObjectType: machineReadableCodeObjectType)
    }
    
    public func generateCode(_ machineReadableCodeObject: AVMetadataMachineReadableCodeObject, inputCorrectionLevel: InputCorrectionLevel) -> UIImage? {
        guard let machineObjectString = machineReadableCodeObject.stringValue else {
            return nil
        }
        
        return self.generateCode(machineObjectString, inputCorrectionLevel: inputCorrectionLevel, machineReadableCodeObjectType: machineReadableCodeObject.type.rawValue)
    }
    
    public func generateCode(_ machineReadableCodeObject: AVMetadataMachineReadableCodeObject) -> UIImage? {
        return self.generateCode(machineReadableCodeObject, inputCorrectionLevel: .Medium)
    }
}

let UnifiedCodeGeneratorSharedInstance = RSUnifiedCodeGenerator()
