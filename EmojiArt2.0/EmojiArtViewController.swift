 //
 //  EmojiArtViewController.swift
 //  EmojiArt
 //
 //  Created by Shannon on 3/22/18.
 //  Copyright © 2018 Shannon. All rights reserved.
 //
 
 import UIKit
 import MobileCoreServices
 
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
 
 
 
 class EmojiArtViewController: UIViewController, UIDropInteractionDelegate, UIScrollViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate, UIPopoverPresentationControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    
    
    // MARK: Public var
    
    var emojiArtView = EmojiArtView()
    var document: EmojiArtDocument?
    var emojis = "🐉🐅🕊🐿🍎".map {String($0)}
    var imageFetcher: ImageFetcher!
    
    enum ImageSource {
        case remote(URL, UIImage)
        case local(Data, UIImage)
        
        var image: UIImage {
            switch self {
            case .remote(_, let image): return image
            case .local(_, let image): return image
            }
        }
    }
    
    var emojiArtBackgroundImage: (ImageSource?) {
        
        didSet {
            
            emojiArtView.backgroundImage = emojiArtBackgroundImage?.image
            
            let size = emojiArtBackgroundImage?.image.size ?? CGSize.zero
            emojiArtView.frame = CGRect(origin: CGPoint.zero, size: size)
            
            scrollView?.contentSize = size
            scrollViewWidth?.constant = size.width
            scrollViewHeight?.constant = size.height
            scrollView?.zoomScale = 1.0
            
            if let dropZone = self.dropZone, size.width > 0, size.height > 0 {
                
                scrollView?.zoomScale = max(dropZone.bounds.size.width / size.width, dropZone.bounds.size.height / size.height)
            }
        }
    }
    
    var emojiArt: EmojiArt? {
        
        get {
            
            if let imageSource = emojiArtBackgroundImage {
                
                let emojis = emojiArtView.subviews.flatMap{$0 as? UILabel}.flatMap{EmojiArt.EmojiInfo(label: $0)}
                
                switch imageSource {
                case .remote(let url, _): return EmojiArt (url: url, emojis: emojis)
                case .local(let imageData, _): return EmojiArt(imageData: imageData, emojis: emojis)
                }
            }
            
            return nil
        }
        
        set {
            
            emojiArtBackgroundImage = nil
            
            emojiArtView.subviews.flatMap{$0 as? UILabel}.forEach {$0.removeFromSuperview()}
            
            let imageData = newValue?.imageData
            let image = (imageData != nil) ? UIImage(data: imageData!) : nil
            if let url = newValue?.url {
                imageFetcher = ImageFetcher(fetch: url) { (url, image) in
                    DispatchQueue.main.async {
                        if image == self.imageFetcher.backup {
                            self.emojiArtBackgroundImage = .local(imageData!, image)
                        } else {
                            self.emojiArtBackgroundImage = .remote(url, image)
                        }
                        newValue?.emojis.forEach {
                            let attributedText = $0.text.attributedString(withTextStyle: .body, ofSize: CGFloat($0.size))
                            self.emojiArtView.addLabel(with: attributedText, centeredAt: CGPoint(x: $0.x, y: $0.y))
                        }
                    }
                }
                imageFetcher.backup = image
                imageFetcher.fetch(url)
            } else if image != nil {
                emojiArtBackgroundImage = .local(imageData!, image!)
                newValue?.emojis.forEach {
                    let attributedText = $0.text.attributedString(withTextStyle: .body, ofSize: CGFloat($0.size))
                    self.emojiArtView.addLabel(with: attributedText, centeredAt: CGPoint(x: $0.x, y: $0.y))
                }
            }
        }
    }
    
    
    // MARK: Private var
    
    private var addingEmoji = false
    private var embeddedDocInfo: DocumentInfoViewController?
    private var suppressBadURLWarning = false
    
    
    private var font: UIFont {
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.preferredFont(forTextStyle: .body).withSize(32.0))
    }
    private let emojiCollectionCellHeight: CGFloat = 80
    private let emojiCollectionCellWidth: CGFloat = 80
    private let emojiCollectionCellWidthMod: CGFloat = 4
    
    private var documentObserver: NSObjectProtocol?
    private var emojiArtViewObserver: NSObjectProtocol?
    
    
    // MARK: IBOutlet
    
    @IBOutlet weak var dropZone: UIView! {
        
        didSet {
            
            dropZone.addInteraction(UIDropInteraction(delegate: self))
        }
    }
    
    @IBOutlet weak var scrollViewHeight: NSLayoutConstraint!
    @IBOutlet weak var scrollViewWidth: NSLayoutConstraint!
    
    @IBOutlet weak var embeddedDocInfoHeight: NSLayoutConstraint!
    @IBOutlet weak var embeddedDocInfoWidth: NSLayoutConstraint!
    
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
    
    @IBOutlet weak var cameraButton: UIBarButtonItem! {
        didSet {
            cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
        }
    }
    
    
    
    // MARK: View Lifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if document?.documentState != .normal { // i.e. if we're taking a pic with the camera for a new background image
            
            documentObserver = NotificationCenter.default.addObserver(
                
                forName: Notification.Name.UIDocumentStateChanged,
                object: document,
                queue: OperationQueue.main,
                using: { notification in
                    print("documentState changed to \(self.document!.documentState)")
                    if self.document!.documentState == .normal, let docInfoVC = self.embeddedDocInfo {
                        docInfoVC.document = self.document
                        self.embeddedDocInfoWidth.constant = docInfoVC.preferredContentSize.width
                        self.embeddedDocInfoHeight.constant = docInfoVC.preferredContentSize.height
                    }
            }
            )
            
            document?.open { success in
                
                if success {
                    
                    self.title = self.document?.localizedName
                    self.emojiArt = self.document?.emojiArt
                    self.emojiArtViewObserver = NotificationCenter.default.addObserver(
                        forName: .EmojiArtViewDidChange,
                        object: self.emojiArtView,
                        queue: OperationQueue.main,
                        using: { notification in
                            self.documentChanged()
                    }
                    )
                }
            }
        }
    }
    
    
    
    // MARK: IB Actions
    
    func documentChanged() {
        
        document?.emojiArt = emojiArt
        if document?.emojiArt != nil {
            
            document?.updateChangeCount(.done)
        }
    }
    
    
    @IBAction func close(_ sender: UIBarButtonItem? = nil) {
        
        if let observer = emojiArtViewObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        if document?.emojiArt != nil {
            
            document?.thumbnail = emojiArtView.snapshot
        }
        
        presentingViewController?.dismiss(animated: true) {
            
            self.document?.close { success in
                
                if let observer = self.documentObserver {
                    
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        }
    }
    
    
    
    @IBAction func addEmoji() {
        addingEmoji = true
        emojiCollectionView.reloadSections(IndexSet(integer: 0))
    }
    
    @IBAction func takeBackgroundPhoto(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [kUTTypeImage as String]
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
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
    
    
    
    
    // MARK: Navigation
    
    override func prepare(for segue:UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Show Document Info" {
            if let destination = segue.destination.contents as? DocumentInfoViewController {
                document?.thumbnail = emojiArtView.snapshot
                destination.document = document
                if let ppc = destination.popoverPresentationController {
                    ppc.delegate = self
                }
            }
        } else if segue.identifier == "EmbedDocumentInfoSegue" {
            embeddedDocInfo = segue.destination.contents as? DocumentInfoViewController
        }
    }
    
    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
        ) -> UIModalPresentationStyle {
        return .none
    }
    
    @IBAction func close(bySegue: UIStoryboardSegue) {
        close()
    }
    
    
    
    // MARK: Image Picker Protocols
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.presentingViewController?.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let image = ((info[UIImagePickerControllerEditedImage] ?? info[UIImagePickerControllerOriginalImage]) as? UIImage)?.scaled(by: 0.25) {
            if let imageData = UIImageJPEGRepresentation(image, 1.0){
                emojiArtBackgroundImage = .local(imageData, image)
                documentChanged()
            } else {
                // TODO: Error
            }
        }
        picker.presentingViewController?.dismiss(animated: true)
    }
    
    
    
    // MARK: Text field protocol
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let inputCell = cell as? TextFieldCollectionViewCell {
            inputCell.textField.becomeFirstResponder()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if addingEmoji && indexPath.section == 0 { // Make text field wider while user is entering text
            return CGSize(width: emojiCollectionCellWidth * emojiCollectionCellWidthMod, height: emojiCollectionCellHeight)
            
        } else { // return cell to normal size
            return CGSize(width: emojiCollectionCellWidth, height: emojiCollectionCellHeight)
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
                if image == self.imageFetcher.backup {
                    if let imageData = UIImageJPEGRepresentation(image, 1.0) {
                        self.emojiArtBackgroundImage = .local(imageData, image)
                        self.documentChanged()
                    } else {
                        self.presentBadURLWarning(for: url)
                    }
                } else {
                    self.emojiArtBackgroundImage = .remote(url, image)
                    self.documentChanged()
                }
            }
        }
        
        session.loadObjects(ofClass: NSURL.self) { nsurls in
            
            if let url = nsurls.first as? URL {
                self.imageFetcher.fetch(url)
            }
            
            session.loadObjects(ofClass: UIImage.self) {images in
                
                if let image = images.first as? UIImage {
                    
                    self.imageFetcher.backup = image
                }
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
    
    // MARK: Alert
    private func presentBadURLWarning(for url: URL?) {
        
        if suppressBadURLWarning != true {
            
            let alert = UIAlertController(title: "Image Drop Failed", message: "Couldn't transfer the dropped image from its source.\n Show this warning in the future?", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(
                title: "Keep Warning",
                style: .default))
            alert.addAction(UIAlertAction(
                title: "StopWarning",
                style: .destructive,
                handler: {action in
                    self.suppressBadURLWarning = true
            }
            ))
            
            present(alert, animated: true)
        }
    }
 }
