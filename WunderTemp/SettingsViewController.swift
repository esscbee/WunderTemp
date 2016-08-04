//
//  SettingsViewController.swift
//  WunderTemp
//
//  Created by Stephen Brennan on 8/4/16.
//  Copyright © 2016 Stephen Brennan. All rights reserved.
//
import UIKit

class SettingsViewController : UIViewController {
    @IBOutlet weak var keyTextField: UITextField!
    
    var key : String?

    override func viewDidLoad() {
        if let k = key {
            keyTextField.text = k
        }
    }
    
    func getKey() -> String? {
        return keyTextField.text
    }
    
    
}