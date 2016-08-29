//
//  ViewController.swift
//  krSSH
//
//  Created by Alex Grinman on 8/26/16.
//  Copyright © 2016 alexgrinman. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        do {
            let kp = try KeyPair.generate("test", keySize: 256, accessGroup: nil)
            let sig = try kp.sign("hellllo")
            print(sig)
        } catch  CryptoError.Generate {
            print("err gen")
        } catch CryptoError.Sign(let s) {
            print("err signing: ", s)
        } catch {
            print("err unknown")
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

