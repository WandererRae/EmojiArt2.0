//
//  EmojiArtView.swift
//  EmojiArt
//
//  Created by Shannon on 3/22/18.
//  Copyright © 2018 Shannon. All rights reserved.
//

import UIKit


protocol EmojiArtViewDelegate: class {
    
    func emojiArtViewDidChange(_ sender: EmojiArtView)
}


extension Notification.Name {
    
    static let EmojiArtViewDidChange = Notification.Name("EmojiArtViewDidChange")
}


class EmojiArtView: UIView, UIDropInteractionDelegate {
    
    // MARK: Public var
    
    var backgroundImage: UIImage? {didSet{setNeedsDisplay()}}

    weak var delegate:EmojiArtViewDelegate?
    
    
    // MARK: Private var
    
    private var labelObservations = [UIView:NSKeyValueObservation]()
    
    
    // MARK: View Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    
        setup()
    }
    
    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        
        if labelObservations[subview] != nil {
            labelObservations[subview] = nil
        }
    }
    
    
    // MARK: Private func
    
    private func setup() {
        
        addInteraction(UIDropInteraction(delegate: self))
    }
    
    
    // MARK: Public func
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
    
        return session.canLoadObjects(ofClass: NSAttributedString.self)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
    
        return UIDropProposal(operation: .copy)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
    
        session.loadObjects(ofClass: NSAttributedString.self) { providers in
        
            let dropPoint = session.location(in: self)
            
            for attributedString in providers as? [NSAttributedString] ?? [] {
            
                self.addLabel(with: attributedString, centeredAt: dropPoint)
                
                self.delegate?.emojiArtViewDidChange(self)
                NotificationCenter.default.post(name:  .EmojiArtViewDidChange, object: self)
            }
        }
        
    }
    
    func addLabel (with attributedString: NSAttributedString, centeredAt point: CGPoint) {
        
        let label = UILabel()
        
        label.backgroundColor = .clear
        label.attributedText = attributedString
        label.sizeToFit()
        label.center = point
        
        addEmojiArtGestureRecognizers(to: label)
        
        addSubview(label)
        
        label.observe(\.center) { (label, change) in
            self.delegate?.emojiArtViewDidChange(self)
            NotificationCenter.default.post(name: .EmojiArtViewDidChange, object: self)
        }
    }
    
    override func draw(_ rect: CGRect) {
        
        backgroundImage?.draw(in: bounds)
    }
}
