import Foundation
import UIKit

enum EncodingError: Error {
  case invalidData
}

// swiftlint:disable private_over_fileprivate
fileprivate let typeIdFolder = "org.berci.zoomnotes.directory"
fileprivate let typeIdDocument = "org.berci.zoomontes.file"

extension DirectoryVM: NSItemProviderWriting {
    static var writableTypeIdentifiersForItemProvider: [String] {
        return [ typeIdFolder ]
    }

    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        if typeIdentifier == typeIdFolder {
            do {
              let archiver = NSKeyedArchiver(requiringSecureCoding: false)
              try archiver.encodeEncodable(self, forKey: NSKeyedArchiveRootObjectKey)
              archiver.finishEncoding()
              let data = archiver.encodedData
              completionHandler(data, nil)
            } catch {
              completionHandler(nil, nil)
            }
        }
        return nil
    }
}

extension FileVM: NSItemProviderWriting {
    static var writableTypeIdentifiersForItemProvider: [String] {
        return [ typeIdDocument ]
    }

    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        if typeIdentifier == typeIdDocument {
            do {
              let archiver = NSKeyedArchiver(requiringSecureCoding: false)
              try archiver.encodeEncodable(self, forKey: NSKeyedArchiveRootObjectKey)
              archiver.finishEncoding()
              let data = archiver.encodedData
              completionHandler(data, nil)
            } catch {
              completionHandler(nil, nil)
            }
        }
        return nil
    }
}

extension DirectoryVM: NSItemProviderReading {
    static var readableTypeIdentifiersForItemProvider: [String] {
        return [ typeIdFolder ]
    }

    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        if typeIdentifier == typeIdFolder {
            do {
              let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
              guard let folder =
                try unarchiver.decodeTopLevelDecodable(
                  DirectoryVM.self, forKey: NSKeyedArchiveRootObjectKey) else {
                    throw EncodingError.invalidData
              }
                return self.init(id: folder.id,
                                 store: folder.store,
                                 name: folder.name,
                                 created: folder.created)
            } catch {
                throw EncodingError.invalidData
            }
        } else {
            throw EncodingError.invalidData
        }
    }
}

extension FileVM: NSItemProviderReading {
    static var readableTypeIdentifiersForItemProvider: [String] {
        return [ typeIdDocument ]
    }

    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        if typeIdentifier == typeIdFolder {
            do {
              let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
              guard let document =
                try unarchiver.decodeTopLevelDecodable(
                  FileVM.self, forKey: NSKeyedArchiveRootObjectKey) else {
                    throw EncodingError.invalidData
              }
                return self.init(id: document.id,
                                 store: document.store,
                                 preview: document.preview.image,
                                 name: document.name,
                                 lastModified: document.lastModified)
            } catch {
                throw EncodingError.invalidData
            }
        } else {
            throw EncodingError.invalidData
        }
    }
}
