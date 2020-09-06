//
//  CodableImage.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit

/// https://gist.github.com/sarunw/5be560ae8b56dd759d422224411f035e
struct Base64ImageWrapper: Codable {
    let image: UIImage

    public init(wrapping image: UIImage) {
        self.image = image
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let base64String = try container.decode(String.self)
        let components = base64String.split(separator: ",")
        if components.count != 2 {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Wrong data format")
        }

        let dataString = String(components[1])

        if let dataDecoded = Data(base64Encoded: dataString, options: .ignoreUnknownCharacters),
            let image = UIImage(data: dataDecoded) {
            self.image = image
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Can't initialize image from data string")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let data = image.jpegData(compressionQuality: 1)
        let prefix = "data:image/jpeg;base64,"
        guard let base64String = data?.base64EncodedString(options: .lineLength64Characters) else {
            throw EncodingError.invalidValue(image, EncodingError.Context(codingPath: [], debugDescription: "Can't encode image to base64 string."))
        }

        try container.encode(prefix + base64String)
    }
}
