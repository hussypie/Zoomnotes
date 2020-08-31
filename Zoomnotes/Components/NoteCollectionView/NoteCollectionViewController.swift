//
//  NoteCollectionViewController.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//
import UIKit
import PencilKit

struct CollectionViewVM {
    let idx: UUID
    let image: UIImage
}

class NoteCollectionViewController : UICollectionViewController, DataModelControllerObserver {
    var dataModelController: DataModelController = DataModelController()
    
    @IBAction func newDrawing(_ sender: Any) {
        let previewImage = UIImage.from(frame: view.frame).withBackground(color: UIColor.white)
        dataModelController.newDrawing(with: previewImage)
    }
    
    override func viewDidLoad() {
        dataModelController.observers.append(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    func dataModelChanged() {
        collectionView.reloadData()
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataModelController.notePreviews.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NoteCollectionViewCell.identifier,
                                                            for: indexPath) as? NoteCollectionViewCell else {
                                                                fatalError("unexpected cell type")
        }
        
        if let index = indexPath.last, index < dataModelController.notePreviews.count {
            cell.imageView.image = dataModelController.notePreviews[index].image
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let navigationController = navigationController else { return }
        
        guard let noteViewController =  NoteViewController.from(storyboard) else { return }
        
        noteViewController.dataModelController = dataModelController
        
        let id = dataModelController.notePreviews[indexPath.last!].idx
        noteViewController.note = dataModelController.dataModel.notes[id]?.root
        
        navigationController.pushViewController(noteViewController, animated: true)
    }
    
}
