//
//  DocumentCollectionViewController.swift
//  FileBrowser
//
//  Created by Berci on 2020. 09. 01..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit
import Combine
import SwiftUI

class DocumentCollectionViewController: UICollectionViewController {
    private var folderVM: FolderBrowserViewModel!
    private var cancellables: Set<AnyCancellable> = []

    lazy var dateLabelFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.dragDelegate = self
        collectionView.dropDelegate = self

        if folderVM == nil {
            folderVM = FolderBrowserViewModel.root()
        }

        folderVM.$title
            .sink { [unowned self] title in self.navigationItem.title = title }
            .store(in: &cancellables)

        folderVM.$nodes
            .sink { [unowned self] _ in self.collectionView.reloadData() }
            .store(in: &cancellables)
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return folderVM.nodes.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let index = indexPath.last else { fatalError() }

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DocumentNodeCell.identifier, for: indexPath) as? DocumentNodeCell else { fatalError() }
        let node = folderVM.nodes[index]

        let name: Binding<String>
        switch node {
        case .file(let doc):
            cell.image.image = doc.preview.image
            cell.nameLabel.text = doc.name
            name = .init(get: { doc.name }, set: { doc.name = $0 })
        case .directory(let folder):
            cell.image.image = UIImage(named: "folder")
            cell.nameLabel.text = folder.name
            name = .init(get: { folder.name }, set: { folder.name = $0 })
        }

        cell.dateLabel.text = dateLabelFormatter.string(from: node.date)

        cell.detailsIndicator.addGestureRecognizer(ZNTapGestureRecognizer { rec in
            if rec.state == .ended {
                let optionsVC = UIHostingController(rootView: VStack {
                    TextField("Name",
                              text: name,
                              onEditingChanged: { _ in },
                              onCommit: {
                                self.folderVM.process(command: .rename(node, to: name.wrappedValue))
                                self.collectionView.reloadData()
                    })
                        .cornerRadius(5)
                        .border(Color.black, width: 3)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: {
                        self.folderVM.process(command: .delete(node))
                        self.collectionView.reloadData()
                    }, label: {
                        Text("Delete") }).foregroundColor(Color.red)
                })
                optionsVC.modalPresentationStyle = .popover
                optionsVC.popoverPresentationController?.sourceView = cell.detailsIndicator
                self.present(optionsVC, animated: true, completion: nil)
            }
        })

        cell.addGestureRecognizer(ZNTapGestureRecognizer { _ in
            switch node {
            case .file:
                return
            case .directory(let subFolder):
                guard let folderBrowser = self.storyboard?.instantiateViewController(identifier: String(describing: DocumentCollectionViewController.self)) as? DocumentCollectionViewController else { return }
                folderBrowser.folderVM = FolderBrowserViewModel(folder: subFolder)
                self.navigationController?.pushViewController(folderBrowser, animated: true)
            }
        })

        return cell

    }

    private func adderSheet() -> UIAlertController {
        let alert = UIAlertController.withActions(title: "Add new...", message: nil, style: .actionSheet) { alert in
            [
                UIAlertAction(title: "Folder", style: .default) { _ in
                    self.folderVM.process(command: .createDirectory)
                },
                UIAlertAction(title: "Document", style: .default) { _ in
                    self.folderVM.process(command: .createFile)
                },
                UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    alert.dismiss(animated: true, completion: { })
                }
            ]
        }
        return alert
    }
}

extension DocumentCollectionViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let index = indexPath.last else { return [] }
        let node = folderVM.nodes[index]
        let itemProvider: NSItemProvider
        switch node {
        case .file(let doc):
            itemProvider = NSItemProvider(object: doc)
        case .directory(let folder):
            itemProvider = NSItemProvider(object: folder)
        }
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = node
        return [ dragItem ]
    }
}

extension DocumentCollectionViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if collectionView.hasActiveDrag {
            return UICollectionViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .forbidden)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let index = coordinator.destinationIndexPath?.last else { return }
        guard index > 0 && index < folderVM.nodes.count else { return }

        guard let node = coordinator.items.first?.dragItem.localObject as? Node else { return }

        let destination = folderVM.nodes[index]
        switch destination {
        case .directory(let folder):
            folderVM.process(command: .move(node, to: folder))
        default:
            return
        }
    }
}
