//
//  DocumentNodeCell.swift
//  FileBrowser
//
//  Created by Berci on 2020. 09. 01..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit

class DocumentNodeCell: UICollectionViewCell {
    static let identifier = "DocumentNodeCell"

    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var detailsIndicator: UIImageView!
}
