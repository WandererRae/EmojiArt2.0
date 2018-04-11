//
//  DocumentInfoViewController.swift
//  EmojiArt2.0
//
//  Created by Bogue Shannon on 4/11/18.
//  Copyright © 2018 Udacity. All rights reserved.
//

import UIKit

class DocumentInfoViewController: UIViewController {
    
    // MARK: Declarations
    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    let topLevelViewBorder: CGFloat = 30
    
    var document: EmojiArtDocument? {
        didSet {
            updateUI()
        }
    }

    // MARK: Storyboard
    
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var createdLabel: UILabel!
    @IBOutlet weak var returnToDocumentButton: UIButton!
    
    @IBOutlet weak var thumbnailAspectRatio: NSLayoutConstraint!
    
    @IBOutlet weak var topLevelView: UIStackView!
    
    @IBAction func done() {
        presentingViewController?.dismiss(animated: true)
    }
    
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        updateUI()
    }
    
    override func viewDidLayoutSubviews() {
        if let fittedSize = topLevelView?.sizeThatFits(UILayoutFittingCompressedSize) {
            preferredContentSize = CGSize(width: fittedSize.width + topLevelViewBorder, height: fittedSize.height + topLevelViewBorder)
        }
    }
    
    
    // MARK: Functions
    
    private func updateUI() {
        if sizeLabel != nil, createdLabel != nil,
            let url = document?.fileURL,
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            sizeLabel.text = "\(attributes[.size] ?? "unknown") bytes"
            if let created = attributes[.creationDate] as? Date {
                createdLabel.text = shortDateFormatter.string(from: created)
            }
        }
        
        if thumbnailImageView != nil, thumbnailAspectRatio != nil, let thumbnail = document?.thumbnail {
            thumbnailImageView.image = thumbnail
            thumbnailImageView.removeConstraint(thumbnailAspectRatio)
            thumbnailAspectRatio = NSLayoutConstraint(
                item: thumbnailImageView,
                attribute: .width,
                relatedBy: .equal,
                toItem: thumbnailImageView,
                attribute: .height,
                multiplier: thumbnail.size.width / thumbnail.size.height,
                constant: 0
            )
            thumbnailImageView.addConstraint(thumbnailAspectRatio)
        }
        
        if presentationController is UIPopoverPresentationController {
            thumbnailImageView?.isHidden = true
            returnToDocumentButton?.isHidden = true
            view.backgroundColor = .clear
        }
    }
}
