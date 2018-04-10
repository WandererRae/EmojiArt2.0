//
//  DocumentBrowserViewController.swift
//  EmojiArt2.0
//
//  Created by Bogue Shannon on 4/2/18.
//  Copyright © 2018 Udacity. All rights reserved.
//

import UIKit


class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate {
   
    var template: URL?

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        allowsDocumentCreation = true
        allowsPickingMultipleItems = false
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            
            template = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Untitled.json")
            
            if template != nil {
                
                allowsDocumentCreation = FileManager.default.createFile(atPath: template!.path, contents: Data())
            }
        }
    }
    
    
    
    // MARK: UIDocumentBrowserViewControllerDelegate
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        
            importHandler(template, .copy)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentURLs documentURLs: [URL]) {
        
        guard let sourceURL = documentURLs.first else { return }
        
        presentDocument(at: sourceURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
        
        presentDocument(at: destinationURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
    }
    
    
    
    // MARK: Document Presentation
    
    func presentDocument(at documentURL: URL) {
        
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let documentViewController = storyBoard.instantiateViewController(withIdentifier: "DocumentMVC")
        
        if let emojiArtViewController = documentViewController.contents as? EmojiArtViewController {
            
            emojiArtViewController.document = EmojiArtDocument(fileURL: documentURL)
        }
        
        present(documentViewController, animated: true)
    }
}

