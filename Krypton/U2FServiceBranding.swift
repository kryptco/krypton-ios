//
//  U2FServiceBranding.swift
//  Krypton
//
//  Created by Alex Grinman on 5/8/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import UIKit

struct U2FBranding {
    let text:UIColor
}
extension KnownU2FApplication {
    var branding:U2FBranding? {
        switch self {
        case .facebook:
            return U2FBranding(text: UIColor(hex: 0x4A67AD))
        case .stripe:
            return U2FBranding(text: UIColor(hex: 0x4E3DF5))
        case .bitbucket:
            return U2FBranding(text: UIColor(hex: 0x5683fb))
        case .gitlab:
            return U2FBranding(text: UIColor(hex: 0xc4452f))
        case .github:
            return U2FBranding(text: UIColor(hex: 0x24292e))
        case .google:
            return U2FBranding(text: UIColor(hex: 0x3cba54))
        case .dropbox:
            return U2FBranding(text: UIColor(hex: 0x0061FF))
        case .sentry:
            return U2FBranding(text: UIColor(hex: 0x2f2936))
        default:
            return nil
        }
    }
}

extension UIView {
    func setBranding(colors: [UIColor]) {
        let gradient = CAGradientLayer()
        
        gradient.frame = self.bounds
        gradient.colors = colors
        
        self.layer.insertSublayer(gradient, at: 0)
    }
}
