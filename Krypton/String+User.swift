//
//  String+User.swift
//  Krypton
//
//  Created by Alex Grinman on 9/28/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation

//MARK: Helper
extension String {
    func getDeviceName() -> String {
        let components = self.components(separatedBy: "@")
        
        guard components.count > 1 else {
            return self
        }
        
        return components[1..<components.count].joined(separator: "")
    }
    
    func removeDotLocal() -> String {
        return self.replacingOccurrences(of: ".local", with: "")
    }

    func sanitizedPhoneNumber() -> String {
        var sanitizedPhone = self.components(separatedBy: CharacterSet.whitespaces).joined(separator: "")
        
        sanitizedPhone = sanitizedPhone.replacingOccurrences(of: "(", with: "")
        sanitizedPhone = sanitizedPhone.replacingOccurrences(of: ")", with: "")
        sanitizedPhone = sanitizedPhone.replacingOccurrences(of: "-", with: "")
        
        if !sanitizedPhone.contains("+") {
            sanitizedPhone = "+1" + sanitizedPhone
        }
        
        return sanitizedPhone
    }
    
    func getEmailDomain() -> String? {
        let components = self.components(separatedBy: "@")
        
        guard components.count == 2 else {
            return nil
        }
        
        return components[1]
    }
    
}

