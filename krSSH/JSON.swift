//
//  JSON.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

protocol JSONConvertable {
    init?(json:[String:AnyObject])
}
