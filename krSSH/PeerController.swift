//
//  PeerController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit
import ContactsUI


class PeerController: KRBaseController, UITableViewDelegate, UITableViewDataSource, CNContactPickerDelegate {

    var peers:[Peer] = []
    
    @IBOutlet weak var addButton:UIButton!
    @IBOutlet weak var tableView:UITableView!

    @IBOutlet weak var emptyView:UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
        peers = PeerManager.shared.all
        
        guard !peers.isEmpty else {
            addButton.isHidden = true
            emptyView.isHidden = false
            return
        }
        
        emptyView.isHidden = true
        addButton.isHidden = false

        peers = peers.sorted(by: { $0.dateAdded > $1.dateAdded })
        
        tableView.reloadData()
        
    }
    
     override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
     override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: Request Flow
    
    @IBAction func requestTapped() {
        
        let contactPicker = CNContactPickerViewController()
        contactPicker.delegate = self;
        contactPicker.navigationController?.navigationBar.tintColor = UIColor.white
        contactPicker.navigationController?.navigationBar.barTintColor = UIColor.app
        contactPicker.displayedPropertyKeys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey]
        
        // 1 phone & 0 email - OR - 0 phone & 1 email
        contactPicker.predicateForSelectionOfContact =
            NSPredicate(format: "(phoneNumbers.@count == 1 &&  emailAddresses.@count == 0) || phoneNumbers.@count == 0 &&  emailAddresses.@count == 1")
        
        present(contactPicker, animated: true, completion: nil)
    }
    
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {        
        if let phoneNumber = contactProperty.value as? CNPhoneNumber {
            picker.dismiss(animated: true, completion: { 
                self.present(self.smsRequest(for: phoneNumber.stringValue.sanitizedPhoneNumber()), animated: true, completion: nil)
            })
        }
        else if let email = contactProperty.value as? String {
            picker.dismiss(animated: true, completion: {
                self.present(self.emailRequest(for: email), animated: true, completion: nil)
            })
        }

    }
    
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        if let phoneNumber = contact.phoneNumbers.first?.value {
            picker.dismiss(animated: true, completion: {
                self.present(self.smsRequest(for: phoneNumber.stringValue.sanitizedPhoneNumber()), animated: true, completion: nil)
            })
        }
        else if let email = contact.emailAddresses.first?.value as? String {
            picker.dismiss(animated: true, completion: {
                self.present(self.emailRequest(for: email), animated: true, completion: nil)
            })
        }

    }

    // MARK: - Table view data source

     func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

     func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return ""
    }
     func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peers.count
    }


     func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "PeerCell", for: indexPath) as! PeerCell

        cell.set(peer: peers[indexPath.row])
        return cell
    }
    
     func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }


    
     func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
 
     func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "showPeerDetail", sender: peers[indexPath.row])
    }

     func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {

            PeerManager.shared.remove(peer: peers[indexPath.row])
            peers = PeerManager.shared.all
            
            self.emptyView.isHidden = !peers.isEmpty

            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.reloadData()
            
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if  let dest = segue.destination as? PeerDetailController,
            let peer = sender as? Peer
        {
            dest.peer = peer
        }
    }
 

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

  
}



