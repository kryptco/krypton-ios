//
//  PeerController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit
import MapKit

class PeerController: UITableViewController, UISearchBarDelegate {

    var peers:[Peer] = []
    
    @IBOutlet weak var addButton:UIButton!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //42.362169, -71.081203 -- cambridge, ma
//        var region = MKCoordinateRegion()
//        region.center = CLLocationCoordinate2D(latitude: 42.362169, longitude: -71.081203)
//        region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//        map.setRegion(region, animated: true)
        
        //addButton.setBorder(color: UIColor.app, cornerRadius: 10, borderWidth: 0.0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
        peers = PeerManager.shared.all
        peers = peers.sorted(by: { $0.dateAdded > $1.dateAdded })
        
        if let me = try? KeyManager.sharedInstance().getMe() {
            peers.append(me)
        }
    
        tableView.reloadData()
        
        //animate plus button
        //addButton.pulse(scale: 1.025, duration: 1.0)
        
        Policy.currentViewController = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()

    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Peers"
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peers.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "PeerCell", for: indexPath) as! PeerCell

        cell.set(peer: peers[indexPath.row])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0
    }


    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
 
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "showPeerDetail", sender: peers[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {

            PeerManager.shared.remove(peer: peers[indexPath.row])
            peers = PeerManager.shared.all
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
