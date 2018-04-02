//
//  Document.swift
//  EmojiArt2.0
//
//  Created by Bogue Shannon on 4/2/18.
//  Copyright © 2018 Udacity. All rights reserved.
//

import UIKit

class Document: UIDocument {
    
    override func contents(forType typeName: String) throws -> Any {
        // Encode your document with an instance of NSData or NSFileWrapper
        return Data()
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        // Load your document from contents
    }
}

