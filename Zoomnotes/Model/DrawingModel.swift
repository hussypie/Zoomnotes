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

struct DrawingModel: Codable {
    var notes: [UUID: NoteModel] = [:]
}

protocol DataModelControllerObserver {
    func dataModelChanged()
}

class DataModelController {
    var dataModel = DrawingModel()

    private let thumbnailQueue = DispatchQueue(label: "ThumbnailQueue", qos: .background)
    private let serializationQueue = DispatchQueue(label: "SerializationQueue", qos: .background)

    var observers: [DataModelControllerObserver] = []

    var notePreviews: [CollectionViewVM] {
        dataModel.notes.values.map { CollectionViewVM(idx: $0.id, image: $0.preview) }
    }

    init() {
        loadDataModel()
    }

    func updatePreview() {
        saveDataModel()
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
                let encoder = JSONEncoder()
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
                    let decoder = JSONDecoder()
                    let data = try Data(contentsOf: url)
                    let dataModel = try decoder.decode(DrawingModel.self, from: data)

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
        didChange()
    }

    func newDrawing(with image: UIImage) {
        let newlyAddedDrawing = NoteModel.default(id: UUID(), image: image, frame: CGRect())
        dataModel.notes[newlyAddedDrawing.id] = newlyAddedDrawing
        updatePreview()
    }
}
