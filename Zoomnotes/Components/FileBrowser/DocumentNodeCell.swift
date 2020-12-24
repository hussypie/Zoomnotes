//
//  DocumentNodeCell.swift
//  FileBrowser
//
//  Created by Berci on 2020. 09. 01..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit
import Combine

class DocumentNodeCell: UICollectionViewCell {
    static let identifier = "DocumentNodeCell"

    lazy var dateLabelFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        dateFormatter.doesRelativeDateFormatting = true
        return dateFormatter
    }()

    var imageView: UIImageView?
    var nameLabel: UILabel?
    var dateLabel: UILabel?
    var detailsIndicator: UIImageView?

    private var cancellables: Set<AnyCancellable> = []

    func setup(vm: FolderBrowserNode) {
        let imageView = UIImageView()
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFit

        self.imageView = self.add(imageView) { [unowned self] make in
            make.top.equalTo(self.snp.top)
            make.leading.equalTo(self.snp.leading)
            make.trailing.equalTo(self.snp.trailing)
        }

        self.nameLabel = UILabel()
        self.dateLabel = UILabel()

        self.detailsIndicator = UIImageView()
        self.detailsIndicator?.image = UIImage(sfSymbol: .chevronDownCircle)
        self.detailsIndicator?.contentMode = .scaleAspectFit
        self.detailsIndicator?.isUserInteractionEnabled = true
        self.detailsIndicator?.snp.makeConstraints { make in
            make.width.equalTo(40)
            make.height.equalTo(40)
        }

        let stack = UIStackView.horizontal(
            UIStackView.vertical(
                self.nameLabel!,
                self.dateLabel!
            ),
            self.detailsIndicator!
        )

        _ = self.add(stack) { [unowned self] make in
            make.top.equalTo(self.imageView!.snp.bottom)
            make.leading.equalTo(self.snp.leading)
            make.trailing.equalTo(self.snp.trailing)
            make.bottom.equalTo(self.snp.bottom)
        }

        vm.$name
            .sink { [unowned self] name in self.nameLabel?.text = name }
            .store(in: &cancellables)

        vm.$lastModified
            .sink { [unowned self] date in
                self.dateLabel?.text = self.dateLabelFormatter.string(from: date)
        }
            .store(in: &cancellables)

        vm.$preview
            .sink { [unowned self] image in self.imageView?.image = image.image }
            .store(in: &cancellables)
    }
}
