//
//  NoteCollectionViewController.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//
import UIKit
import PencilKit

class NoteCollectionViewController : UICollectionViewController, DataModelControllerObserver {
    var dataModelController: DataModelController = DataModelController()
    
    @IBAction func newDrawing(_ sender: Any) {
        dataModelController.newDrawing(with: UIImage.from(frame: view.frame).withBackground(color: UIColor.white))
    }
    
    override func viewDidLoad() {
        dataModelController.thumbnailTraitCollection = traitCollection
        dataModelController.observers.append(self)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        dataModelController.thumbnailTraitCollection = traitCollection
    }
    
    func dataModelChanged() {
        collectionView.reloadData()
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataModelController.notes.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NoteCollectionViewCell.identifier,
                                                            for: indexPath) as? NoteCollectionViewCell else {
                                                                fatalError("unexpected cell type")
        }
        
        if let index = indexPath.last, index < dataModelController.thumbnails.count {
            cell.imageView.image = dataModelController.thumbnails[index]
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let noteViewController = storyboard?.instantiateViewController(withIdentifier: String(describing: NoteViewController.self)) as? NoteViewController,
            let navigationController = navigationController else {
                return
        }
        
        // Transition to the drawing view controller.
        noteViewController.dataModelController = dataModelController
        noteViewController.note = dataModelController.notes[indexPath.last!]
        navigationController.pushViewController(noteViewController, animated: true)
    }
    
}
