 //
 //  EmojiArtViewController.swift
 //  EmojiArt
 //
 //  Created by Shannon on 3/22/18.
 //  Copyright © 2018 Shannon. All rights reserved.
 //
 
 import UIKit
 
 extension EmojiArt.EmojiInfo {
    init? (label: UILabel) {
        if let attributedText = label.attributedText, let font = attributedText.font {
            x = Int(label.center.x)
            y = Int(label.center.y)
            text = attributedText.string
            size = Int(font.pointSize)
        } else {
            return nil
        }
    }
 }
 
 
 
 class EmojiArtViewController: UIViewController, UIDropInteractionDelegate, UIScrollViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    
    
    
    // MARK: Definitions
    
    var emojiArtView = EmojiArtView()
    var document: EmojiArtDocument?
    var emojis = "🐉🐅🕊🐿🍎".map {String($0)}
    var imageFetcher: ImageFetcher!
    
    var emojiArtBackgroundImage: (url: URL?, image: UIImage?) {
        
        get {
            
            return (_emojiArtBackgroundImageURL, emojiArtView.backgroundImage)
        }
        
        set {
            
            _emojiArtBackgroundImageURL = newValue.url
            
            scrollView?.zoomScale = 1.0
            
            emojiArtView.backgroundImage = newValue.image
            
            let size = newValue.image?.size ?? CGSize.zero
            emojiArtView.frame = CGRect(origin: CGPoint.zero, size: size)
            
            scrollView?.contentSize = size
            scrollViewWidth?.constant = size.width
            scrollViewHeight?.constant = size.height
            
            if let dropZone = self.dropZone, size.width > 0, size.height > 0 {
                
                scrollView?.zoomScale = max(dropZone.bounds.size.width / size.width, dropZone.bounds.size.height / size.height)
            }
        }
    }
    
    var emojiArt: EmojiArt? {
        
        get {
            
            if let url = emojiArtBackgroundImage.url {
                
                let emojis = emojiArtView.subviews.flatMap{$0 as? UILabel}.flatMap{EmojiArt.EmojiInfo(label: $0)}
                return EmojiArt (url: url, emojis: emojis)
            }
            
            return nil
        }
        
        set {
            
            emojiArtBackgroundImage = (nil, nil)
            
            emojiArtView.subviews.flatMap{$0 as? UILabel}.forEach {$0.removeFromSuperview()}
            
            if let url = newValue?.url {
                imageFetcher = ImageFetcher(fetch: url) { (url, image) in
                    DispatchQueue.main.async {
                        self.emojiArtBackgroundImage = (url, image)
                        newValue?.emojis.forEach {
                            let attributedText = $0.text.attributedString(withTextStyle: .body, ofSize: CGFloat($0.size))
                            self.emojiArtView.addLabel(with: attributedText, centeredAt: CGPoint(x: $0.x, y: $0.y))
                        }
                    }
                }
            }
        }
    }
    
    
    
    private var addingEmoji = false
    private var _emojiArtBackgroundImageURL: URL?
    
    private var font: UIFont {
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.preferredFont(forTextStyle: .body).withSize(32.0))
    }
    
    
    
    @IBOutlet weak var dropZone: UIView! {
        
        didSet {
            
            dropZone.addInteraction(UIDropInteraction(delegate: self))
        }
    }
    
    @IBOutlet weak var scrollViewHeight: NSLayoutConstraint!
    @IBOutlet weak var scrollViewWidth: NSLayoutConstraint!
    
    @IBOutlet weak var scrollView: UIScrollView! {
        
        didSet {
            
            scrollView.minimumZoomScale = 0.1
            scrollView.maximumZoomScale = 5.0
            scrollView.delegate = self
            scrollView.addSubview(emojiArtView)
        }
    }
    
    @IBOutlet weak var emojiCollectionView: UICollectionView! {
        didSet {
            emojiCollectionView.dataSource = self
            emojiCollectionView.delegate = self
            emojiCollectionView.dragDelegate = self
            emojiCollectionView.dropDelegate = self
            emojiCollectionView.dragInteractionEnabled = true
        }
    }
    
    

    // MARK: View Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        document?.open { success in
            
            if success {
                
                self.title = self.document?.localizedName
                self.emojiArt = self.document?.emojiArt
            }
        }
    }

    
    
    // MARK: IB Actions
    
    @IBAction func save(_ sender: UIBarButtonItem? = nil) {
        //Save button for documents is bad form.  There should be a delegate that tells the VC when a change is made (autosave).

        document?.emojiArt = emojiArt
        if document?.emojiArt != nil {
            
            document?.updateChangeCount(.done)
        }
    }
    
    
    
    @IBAction func close(_ sender: UIBarButtonItem) {
        
        save()
        //Only because there's no autosave
        
        if document?.emojiArt != nil {
            
            document?.thumbnail = emojiArtView.snapshot
            // TODO: Yes, EmojiArtDocument, you do have member "thumbnail"
        }
        
        dismiss(animated: true) {
            self.document?.close()
        }
    }
    
    
    
    @IBAction func addEmoji() {
        addingEmoji = true
        emojiCollectionView.reloadSections(IndexSet(integer: 0))
    }
    
    
    
    //MARK: Emoji Collection View Protocols
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        switch section {
            
        case 0: return 1
        case 1: return emojis.count
        default: return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if indexPath.section == 1 {  // Show all of the current emojis

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCell", for: indexPath)
            
            if let emojiCell = cell as? EmojiCollectionViewCell {
                
                let text = NSAttributedString(string: emojis[indexPath.item], attributes: [.font: font])
                emojiCell.label.attributedText = text
            }
            
            return cell
            
            
        } else if addingEmoji { // If actively adding another emoji, first cell should display text field
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiInputCell", for: indexPath)
            
            if let inputCell = cell as? TextFieldCollectionViewCell {
                
                inputCell.resignationHandler = { [weak self, unowned inputCell] in
                    
                    if let text = inputCell.textField.text {
                        
                        self?.emojis = (text.map {String($0)} + self!.emojis).uniquified
                    }
                    
                    self?.addingEmoji = false
                    self?.emojiCollectionView.reloadData()
                }
            }
            
            return cell
            
        } else { // If not actively adding another emoji, the first cell should display "+"
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddEmojiButtonCell", for: indexPath)
            return cell
        }
    }
    
    
    
    // MARK: Text field protocol
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let inputCell = cell as? TextFieldCollectionViewCell {
            inputCell.textField.becomeFirstResponder()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if addingEmoji && indexPath.section == 0 { // Make text field wider while user is entering text
            return CGSize(width:300, height: 80)
            
        } else { // return cell to normal size
            return CGSize(width: 80, height: 80)
        }
    }
    
    
    
    // MARK: Drag and Drop Protocol
    
    // Function added for simplifying code
    private func dragItems(at indexPath: IndexPath) -> [UIDragItem] {
        
        if !addingEmoji, let attributedString = (emojiCollectionView.cellForItem(at: indexPath) as? EmojiCollectionViewCell)?.label.attributedText {
            
            let dragItem = UIDragItem(itemProvider: NSItemProvider(object: attributedString))
            dragItem.localObject = attributedString
            
            return [dragItem]
            
        } else { // Don't allow drag/drop when adding emoji
            
            return []
        }
    }
    

    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        
        session.localContext = collectionView
        return dragItems(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        
        return dragItems(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        
        return session.canLoadObjects(ofClass: NSAttributedString.self)
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        
        if let indexPath = destinationIndexPath, indexPath.section == 1 { // Only drag/drop emoji cells within the array of emoji
            
            let isSelf = (session.localDragSession?.localContext as? UICollectionView) == collectionView
            
            return UICollectionViewDropProposal(operation: isSelf ? .move:.copy, intent: .insertAtDestinationIndexPath)
            
        } else {
            
            return UICollectionViewDropProposal(operation: .cancel)
        }
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        
        let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath (item: 0, section: 0)
        
        for item in coordinator.items {
            
            if let sourceIndexPath = item.sourceIndexPath {
                
                if let attributedString = item.dragItem.localObject as? NSAttributedString {
                    
                    collectionView.performBatchUpdates({
                        emojis.remove(at: sourceIndexPath.item)
                        emojis.insert(attributedString.string, at: destinationIndexPath.item)
                        collectionView.deleteItems(at: [sourceIndexPath])
                        collectionView.insertItems(at: [destinationIndexPath])
                    })
                    
                    coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
                }
                
            } else {
                
                let placeholderContext = coordinator.drop(
                    item.dragItem,
                    to: UICollectionViewDropPlaceholder(
                        insertionIndexPath: destinationIndexPath,
                        reuseIdentifier: "DropPlaceholderCell"))
                
                item.dragItem.itemProvider.loadObject(ofClass: NSAttributedString.self) { (provider, error) in
                    DispatchQueue.main.async {
                        
                        if let attributedString = provider as? NSAttributedString {
                            
                            placeholderContext.commitInsertion(dataSourceUpdates: {insertionIndexPath in
                                self.emojis.insert(attributedString.string, at: insertionIndexPath.item)
                            })
                        }
                    }
                }
            }
        }
    }
    
    func dropInteraction (_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        
        return session.canLoadObjects(ofClass: NSURL.self) && session.canLoadObjects(ofClass: UIImage.self)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        
        imageFetcher = ImageFetcher() { (url, image) in
            
            DispatchQueue.main.async {
                
                self.emojiArtBackgroundImage = (url, image)
            }
        }
        
        session.loadObjects(ofClass: NSURL.self) { nsurls in
            
            if let url = nsurls.first as? URL {
                
                self.imageFetcher.fetch(url)
            }
        }
        
        session.loadObjects(ofClass: UIImage.self) {images in
            
            if let image = images.first as? UIImage {
                
                self.imageFetcher.backup = image
            }
        }
    }

    
    
    //MARK: Scroll View Protocols
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        
        scrollViewWidth.constant = scrollView.contentSize.width
        scrollViewHeight.constant = scrollView.contentSize.height
    }
    
    func viewForZooming (in scrollView: UIScrollView) -> UIView? {
        
        return emojiArtView
    }
 }
