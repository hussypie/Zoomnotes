//
//  NoteImage.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 18..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit

class CodableImage: Codable {
    let image: UIImage

    init(wrapping image: UIImage) {
        self.image = image
    }

    enum CodingKeys: String, CodingKey {
        case imageData
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let imageData = try container.decode(Data.self, forKey: .imageData)
        self.image = UIImage(data: imageData)!
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let imageData = image.jpegData(compressionQuality: 1)

        try container.encode(imageData, forKey: .imageData)
    }
}
