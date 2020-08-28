//
//  NoteViewController+DragDrop.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 27..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension NoteLevelPreview : UIDragInteractionDelegate {
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        let itemProvider = NSItemProvider(object: note)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.previewProvider = {
            return UIDragPreview(view: self)
        }
        return [ dragItem ]
    }
}
