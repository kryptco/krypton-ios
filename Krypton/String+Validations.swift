//
//  String+Validations.swift
//  Krypton
//
//  Created by Alex Grinman on 10/28/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

enum ExpressionRegex:String {
    case email = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    
    var predicate:NSPredicate {
        return NSPredicate(format:"SELF MATCHES %@", self.rawValue)
    }
}
extension String {
    
    var isValidEmail:Bool {
        return self.isEmpty == false && ExpressionRegex.email.predicate.evaluate(with: self)
    }
    
    var isValidName:Bool {
        return self.isEmpty == false
    }
    
}
