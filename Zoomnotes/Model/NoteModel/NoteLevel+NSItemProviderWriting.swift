//
//  NoteLevel+NSItemProviderWriting.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 28..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import MobileCoreServices

let noteLevelTypeId: String = "com.bercis.ideas.NoteLevel"

extension NoteModel.NoteLevel: NSItemProviderWriting {
    static var writableTypeIdentifiersForItemProvider: [String] {
        return [ noteLevelTypeId ]
    }

    enum NoteLevelLoadingError: Error {
        case archivingFailed(Error)
    }

    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        guard typeIdentifier == noteLevelTypeId else { return nil }
        do {
            let archiver = NSKeyedArchiver(requiringSecureCoding: false)
            try archiver.encodeEncodable(self, forKey: NSKeyedArchiveRootObjectKey)
            archiver.finishEncoding()
            let data = archiver.encodedData

            completionHandler(data, nil)
        } catch {
            completionHandler(nil, NoteLevelLoadingError.archivingFailed(error))
        }
        return nil
    }
}

extension NoteModel.NoteLevel: NSItemProviderReading {
    static var readableTypeIdentifiersForItemProvider: [String] {
        return [ noteLevelTypeId ]
    }

    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        let archiver = try NSKeyedUnarchiver(forReadingFrom: data)
        let noteLevel = try archiver.decodeTopLevelDecodable(NoteModel.NoteLevel.self, forKey: NSKeyedArchiveRootObjectKey)!
        return self.init(data: noteLevel.data,
                         children: noteLevel.children,
                         preview: noteLevel.previewImage.image,
                         frame: noteLevel.frame)

    }
}
