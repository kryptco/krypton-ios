//
//  String+User.swift
//  krSSH
//
//  Created by Alex Grinman on 9/28/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

//MARK: Helper
extension String {
    func getUserOrNil() -> String? {
        let components = self.components(separatedBy: "@")
        
        guard components.count > 1 else {
            return nil
        }
        
        return components[0]
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
    
}

