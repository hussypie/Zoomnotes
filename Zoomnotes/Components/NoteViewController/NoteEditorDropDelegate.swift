//
//  NoteEditorDropDelegate.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 05..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import UIKit

class NoteEditorDropDelegate: NSObject, UIDropInteractionDelegate {
    typealias LocationProvider = (UIDropSession) -> CGPoint
    typealias OnDropCallback = (CGPoint, UIImage) -> Void

    private let locationProvider: LocationProvider
    private let onDrop: OnDropCallback

    init(locationProvider: @escaping LocationProvider,
         onDrop: @escaping OnDropCallback
    ) {
        self.locationProvider = locationProvider
        self.onDrop = onDrop
    }

    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: UIImage.self)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: UIImage.self) { [unowned self] imageItems in
            guard let image = (imageItems as? [UIImage])?.first else { return }
            let location = self.locationProvider(session)
            self.onDrop(location, image)
        }
    }
}
