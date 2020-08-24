//
//  DrawingModel.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 08. 13..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit
import PencilKit
import os

struct DrawingModel : Codable {
    static let canvasWidth: CGFloat = 1280
    
    var notes: [NoteModel] = []
}

protocol DataModelControllerObserver {
    func dataModelChanged()
}

class DataModelController {
    static let thumbnailSize = CGSize(width: 256, height: 192)
    
    var dataModel = DrawingModel()
    
    var thumbnails: [UIImage] = []
    var thumbnailTraitCollection = UITraitCollection() {
        didSet {
            if oldValue.userInterfaceStyle != thumbnailTraitCollection.userInterfaceStyle {
                generateAllThumbnails()
            }
        }
    }
    
    private let thumbnailQueue = DispatchQueue(label: "ThumbnailQueue", qos: .background)
    private let serializationQueue = DispatchQueue(label: "SerializationQueue", qos: .background)
    
    var observers: [DataModelControllerObserver] = []
    
    var notes: [NoteModel] {
        get { dataModel.notes }
        set { dataModel.notes = newValue }
    }
    
    init() {
        loadDataModel()
    }
    
    func updateDrawing(for note: NoteModel, with image: UIImage) {
        let noteIndex: Int = dataModel.notes.firstIndex { $0.id == note.id }!
        self.updateThumbnail(image, at: noteIndex)
        saveDataModel()
    }
    
    private func generateAllThumbnails() {
        for index in notes.indices {
            generateThumbnail(index)
        }
    }
    
    private func generateThumbnail(_ index: Int) {
        let note = notes[index]
        let aspectRatio = DataModelController.thumbnailSize.width / DataModelController.thumbnailSize.height
        let thumbnailRect = CGRect(x: 0, y: 0, width: DrawingModel.canvasWidth, height: DrawingModel.canvasWidth / aspectRatio)
        let thumbnailScale = UIScreen.main.scale * DataModelController.thumbnailSize.width / DrawingModel.canvasWidth
        let traitCollection = thumbnailTraitCollection
        
        thumbnailQueue.async {
            traitCollection.performAsCurrent {
                let image = note.root.data.drawing.image(from: thumbnailRect, scale: thumbnailScale)
                DispatchQueue.main.async {
                    self.updateThumbnail(image, at: index)
                }
            }
        }
    }
    
    private func updateThumbnail(_ image: UIImage, at index: Int) {
        thumbnails[index] = image
        didChange()
    }
    
    private func didChange() {
        for observer in self.observers {
            observer.dataModelChanged()
        }
    }
    
    private var saveURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths.first!
        return documentsDirectory.appendingPathComponent("Zoomnotes.data")
    }
    
    func saveDataModel() {
        let savingDataModel = dataModel
        let url = saveURL
        serializationQueue.async {
            do {
                let encoder = PropertyListEncoder()
                let data = try encoder.encode(savingDataModel)
                try data.write(to: url)
            } catch {
                os_log("Could not save data model: %s", type: .error, error.localizedDescription)
            }
        }
    }
    
    private func loadDataModel() {
        let url = saveURL
        serializationQueue.async {
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    let decoder = PropertyListDecoder()
                    let data = try Data(contentsOf: url)
                    let dataModel = try decoder.decode(DrawingModel.self, from: data)
                    
                    for note in dataModel.notes {
                        note.updateDrawingCallback = { _ in self.saveDataModel() }
                    }
                    
                    DispatchQueue.main.async {
                        self.setLoadedDataModel(dataModel)
                    }
                } catch {
                    os_log("Could not load data model: %s", type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    private func setLoadedDataModel(_ dataModel: DrawingModel) {
        self.dataModel = dataModel
        thumbnails = Array(repeating: UIImage(), count: dataModel.notes.count)
        generateAllThumbnails()
    }
    
    func newDrawing(with image: UIImage) {
        let newlyAddedDrawing = NoteModel.default(controller: self)
        dataModel.notes.append(newlyAddedDrawing)
        thumbnails.append(image)
        updateDrawing(for: newlyAddedDrawing, with: image)
    }
}


