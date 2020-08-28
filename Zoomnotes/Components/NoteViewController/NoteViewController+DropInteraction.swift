//
//  NoteViewController+DropInteraction.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 28..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

extension NoteViewController: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NoteModel.NoteLevel.self)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .move)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: NoteModel.NoteLevel.self) { noteLevel in
            let level = noteLevel as! NoteModel.NoteLevel
            
        
        }
    }
}
