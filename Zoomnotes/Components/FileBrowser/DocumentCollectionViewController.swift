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
import CoreData

class DocumentCollectionViewController: UICollectionViewController {
    private var folderVM: FolderBrowserViewModel!
    private var cancellables: Set<AnyCancellable> = []

    lazy var dateLabelFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        dateFormatter.doesRelativeDateFormatting = true
        return dateFormatter
    }()

    lazy var moc: NSManagedObjectContext = {
        // swiftlint:disable:next force_cast
        return (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.dragDelegate = self
        collectionView.dropDelegate = self

        self.navigationItem.leftItemsSupplementBackButton = true

        if folderVM == nil {
            folderVM = FolderBrowserViewModel.root(defaults: UserDefaults.standard,
                                                   using: self.moc)
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
        guard let index = indexPath.last else { fatalError("Indexpath has no `last` component") }

        let node = folderVM.nodes[index]
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: DocumentNodeCell.self),
                                                      for: indexPath) as? DocumentNodeCell else {
                                                        fatalError("Unknown cell type dequeued")
        }
        return nodeCell(using: cell, with: node)
    }

    private func nodeCell(using cell: DocumentNodeCell, with node: Node) -> DocumentNodeCell {
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

        cell.detailsIndicator.addGestureRecognizer(ZNTapGestureRecognizer { _ in
            let editor = NodeDetailEditor(name: name,
                                          onDelete: {
                                            self.folderVM.process(command: .delete(node))
                                            self.dismiss(animated: true, completion: nil)
            })

            let optionsVC = UIHostingController(rootView: editor)

            optionsVC.modalPresentationStyle = .popover
            optionsVC.popoverPresentationController?.sourceView = cell.detailsIndicator
            optionsVC.preferredContentSize = CGSize(width: 200,
                                                    height: optionsVC.view.intrinsicContentSize.height)

            self.present(optionsVC, animated: true, completion: nil)
        })

        cell.addGestureRecognizer(ZNTapGestureRecognizer { _ in
            switch node {
            case .file(let note):
                self.openNoteEditor(for: note)
            case .directory(let subFolder):
                self.navigateTo(folder: subFolder)
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

    private func navigateTo(folder: DirectoryVM) {
        guard let destinationViewController =
            DocumentCollectionViewController.from(storyboard: self.storyboard) else { return }
        destinationViewController.folderVM = self.folderVM.subFolderBrowserVM(for: folder)
        self.navigationController?.pushViewController(destinationViewController, animated: true)
    }

    private func openNoteEditor(for note: FileVM) {
        print("Open note view controller")
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

extension DocumentCollectionViewController {
    @IBAction func onSettingsButtonClick(_ sender: Any) {
        let settingsController = UIHostingController(rootView: SettingsView())
        self.navigationController?.pushViewController(settingsController, animated: true)
    }

    @IBAction func onAddNewButtonClicked(_ sender: Any) {
        guard let addButton = sender as? UIBarButtonItem else { return }
        let adderSheet = UIAlertController(title: nil,
                                           message: "Add a note or a folder",
                                           preferredStyle: .actionSheet)
        adderSheet.addAction(
            UIAlertAction(title: "Note",
                          style: .default) { _ in
                            self.folderVM.process(command: .createFile)
        })
        adderSheet.addAction(
            UIAlertAction(title: "Folder",
                          style: .default) { _ in
                            self.folderVM.process(command: .createDirectory)
        })

        adderSheet.popoverPresentationController?.barButtonItem = addButton

        self.present(adderSheet, animated: true, completion: nil)
    }

}

extension DocumentCollectionViewController {
    static func from(storyboard: UIStoryboard?) -> DocumentCollectionViewController? {
        return storyboard?.instantiateViewController(identifier: String(describing: DocumentCollectionViewController.self)) as? DocumentCollectionViewController
    }
}
