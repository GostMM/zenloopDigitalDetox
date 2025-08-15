//
//  ActionViewController.swift
//  zenloopaction - STUB FILE - TO BE REMOVED
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class ActionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Stub implementation
    }

    @IBAction func done() {
        self.extensionContext!.completeRequest(returningItems: self.extensionContext!.inputItems, completionHandler: nil)
    }
}