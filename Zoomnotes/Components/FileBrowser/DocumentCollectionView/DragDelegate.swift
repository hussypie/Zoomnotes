//
//  DragDelegate.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 12. 24..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension DocumentCollectionViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath
    ) -> [UIDragItem] {
        guard let index = indexPath.last else { return [] }
        let node = folderVM.nodes[index]

        let itemProvider: NSItemProvider
        switch node.store {
        case .document:
            itemProvider = NSItemProvider(object: FolderBrowserNode.DocumentWrapper(node: node))
        case .directory:
            itemProvider = NSItemProvider(object: FolderBrowserNode.DirectoryWrapper(node: node))
        }

        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = node

        self.logger.info("Beginning drag session with node (id: \(node.id))")

        return [ dragItem ]
    }
}
