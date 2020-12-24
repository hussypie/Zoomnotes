//
//  DocumentViewController+DataSource.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 12. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

extension DocumentCollectionViewController {
    func makeDataSource() -> UICollectionViewDiffableDataSource<Section, FolderBrowserNode> {
        return UICollectionViewDiffableDataSource(
            collectionView: self.collectionView,
            cellProvider: {  [unowned self] collectionView, indexPath, node in
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: DocumentNodeCell.identifier,
                    // only DocumentNodeCell shoud be dequeued
                    // swiftlint:disable:next force_cast
                    for: indexPath) as! DocumentNodeCell
                cell.setup(vm: node)

                cell.imageView?.addGestureRecognizer(ZNTapGestureRecognizer { _ in
                    switch node.store {
                    case .document(let id):
                        self.openNoteEditor(node: node, for: id, with: node.name)
                    case .directory(let id):
                        self.navigateTo(folder: id, with: node.name)
                    }
                })

                cell.detailsIndicator?.addGestureRecognizer(ZNTapGestureRecognizer { _ in
                    let editor = NodeDetailEditor(
                        name: node.name,
                        onTextfieldEditingChanged: { [unowned self] name in
                            self.folderVM
                                .rename(node: node, to: name)
                                .sink(
                                    receiveDone: { [unowned self] in
                                        self.logger.info("Renamed node (id: \(node.id)) to \(name)")
                                    },
                                    receiveError: { [unowned self] in
                                        self.logger.warning("Renamed node (id: \(node.id)), reason: \($0.localizedDescription)")
                                    },
                                    receiveValue: { node.name = name })
                                .store(in: &self.cancellables)
                            self.dismiss(animated: true, completion: nil)
                        },
                        onDelete: { [unowned self] in
                            self.logger.info("Delete node button tapped")
                            self.delete(node: node) }
                    )

                    let optionsVC = UIHostingController(rootView: editor)

                    optionsVC.modalPresentationStyle = .popover
                    optionsVC.popoverPresentationController?.sourceView = cell.detailsIndicator
                    optionsVC.preferredContentSize = CGSize(width: 200,
                                                            height: optionsVC.view.intrinsicContentSize.height)

                    self.present(optionsVC, animated: true, completion: nil)
                })

                return cell
            })
    }
}

extension DocumentCollectionViewController {
    func makeGridLayout(itemsInRow: Int) -> NSCollectionLayoutSection {
        assert(itemsInRow > 0)
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(itemsInRow)),
            heightDimension: .fractionalHeight(1)
        ))

        item.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(200)
            ),
            subitem: item,
            count: itemsInRow
        )

        return NSCollectionLayoutSection(group: group)
    }

    func makeCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [unowned self] _, _ in
            switch self.traitCollection.horizontalSizeClass {
            case .regular:
                return self.makeGridLayout(itemsInRow: 4)
            default:
                return self.makeGridLayout(itemsInRow: 2)
            }
        }
    }
}

extension DocumentCollectionViewController {
    func makeCollectionView() -> UICollectionView {
        return UICollectionView(frame: .zero,
                                collectionViewLayout: makeCollectionViewLayout())
    }
}
