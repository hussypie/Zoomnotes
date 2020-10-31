import Foundation
import UIKit

enum EncodingError: Error {
  case invalidData
}

// swiftlint:disable private_over_fileprivate
fileprivate let typeIdFolder = "org.berci.zoomnotes.directory"
fileprivate let typeIdDocument = "org.berci.zoomontes.file"

extension FolderBrowserNode {
    class DirectoryWrapper: NSObject, Codable {
        let node: FolderBrowserNode
        init(node: FolderBrowserNode) { self.node = node }
    }

    class DocumentWrapper: NSObject, Codable {
        let node: FolderBrowserNode
        init(node: FolderBrowserNode) { self.node = node }
    }
}

extension FolderBrowserNode.DocumentWrapper: NSItemProviderWriting {
    private static let typeId = typeIdDocument
    static var writableTypeIdentifiersForItemProvider: [String] {
        return [ typeId ]
    }

    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        guard typeIdentifier == FolderBrowserNode.DocumentWrapper.typeId else { return nil }
        return loadDataI(codee: self, forItemProviderCompletionHandler: completionHandler)
    }
}

extension FolderBrowserNode.DocumentWrapper: NSItemProviderReading {
    static var readableTypeIdentifiersForItemProvider: [String] {
        return [ typeId ]
    }

    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        guard typeIdentifier == FolderBrowserNode.DocumentWrapper.typeId else {
            throw EncodingError.invalidData
        }
        return try objectI(withItemProviderData: data)
    }
}

extension FolderBrowserNode.DirectoryWrapper: NSItemProviderWriting {
    private static let typeId = typeIdFolder
    static var writableTypeIdentifiersForItemProvider: [String] {
        return [ typeId ]
    }

    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        guard typeIdentifier == FolderBrowserNode.DirectoryWrapper.typeId else { return nil }
        return loadDataI(codee: self, forItemProviderCompletionHandler: completionHandler)
    }
}

extension FolderBrowserNode.DirectoryWrapper: NSItemProviderReading {
    static var readableTypeIdentifiersForItemProvider: [String] {
        return [ typeId ]
    }

    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        guard typeIdentifier == FolderBrowserNode.DirectoryWrapper.typeId else {
            throw EncodingError.invalidData
        }
        return try objectI(withItemProviderData: data)
    }
}

fileprivate func loadDataI<Codee: Encodable>(
    codee: Codee,
    forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void
) -> Progress? {
    do {
      let archiver = NSKeyedArchiver(requiringSecureCoding: false)
      try archiver.encodeEncodable(codee, forKey: NSKeyedArchiveRootObjectKey)
      archiver.finishEncoding()
      let data = archiver.encodedData
      completionHandler(data, nil)
    } catch {
      completionHandler(nil, nil)
    }
    return nil
}

fileprivate func objectI<D: Decodable>(withItemProviderData data: Data) throws -> D {
    do {
      let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
      guard let thing =
        try unarchiver.decodeTopLevelDecodable(D.self, forKey: NSKeyedArchiveRootObjectKey) else {
            throw EncodingError.invalidData
      }
        return thing
    } catch {
        throw EncodingError.invalidData
    }
}
