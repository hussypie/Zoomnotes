//
//  DropDelegate.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 12. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension DocumentCollectionViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        if collectionView.hasActiveDrag {
            return UICollectionViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .forbidden)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let index = coordinator.destinationIndexPath?.last else { return }

        guard let node =
            coordinator.items.first?.dragItem.localObject as? FolderBrowserNode else {
                return
        }

        let destination = folderVM.nodes[index]
        switch destination.store {
        case .directory(let id):
            self.logger.info("Dropping dragged node on directory node")
            folderVM
                .move(node: node, to: id)
                .sink(
                    receiveDone: { },
                    receiveError: { [unowned self] error in
                        self.logger.warning("Could not move nodes to new parent, reason: \(error.localizedDescription)")
                    },
                    receiveValue: { [unowned self] _ in
                        self.logger.info("Dropped node (id: \(node.id)) into new parent (id: \(destination.id))")
                    }
            ).store(in: &self.cancellables)

        default:
            self.logger.info("Tried to drop dragged node on non-directory node")
            return
        }
    }
}
