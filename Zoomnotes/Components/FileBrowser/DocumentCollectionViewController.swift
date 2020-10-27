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

    func deleteAlertController(for node: FolderBrowserNode) -> UIAlertController {
        let alert = UIAlertController(
            title: "Delete \(node.name)?",
            message: "Are you sure to delete \(node.name)?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete",
                                      style: .destructive,
                                      handler: { _ in self.folderVM.delete(node: node) }))
        return alert
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.dragDelegate = self
        collectionView.dropDelegate = self

        self.navigationItem.leftItemsSupplementBackButton = true

        Just(folderVM)
            .eraseToAnyPublisher()
            .setFailureType(to: Error.self)
            .flatMap { vm -> AnyPublisher<FolderBrowserViewModel, Error> in
                if vm != nil {
                    return Just(vm!)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()

                }
                // swiftlint:disable:next force_cast
                let access = (UIApplication.shared.delegate as! AppDelegate).access
                let directoryAccess = DirectoryAccessImpl(access: access)
                return FolderBrowserViewModel
                    .root(defaults: UserDefaults.standard, access: directoryAccess)
        }
        .sink(receiveCompletion: { _ in },
              receiveValue: { folderVM in
                self.folderVM = folderVM

                folderVM.$title
                    .receive(on: DispatchQueue.main)
                    .sink { [unowned self] title in self.navigationItem.title = title }
                    .store(in: &self.cancellables)

                folderVM.$nodes
                    .receive(on: DispatchQueue.main)
                    .sink { [unowned self] _ in self.collectionView.reloadData() }
                    .store(in: &self.cancellables)

        })
            .store(in: &cancellables)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let folderVM = self.folderVM {
            return folderVM.nodes.count
        }
        return 0
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

    private func nodeCell(using cell: DocumentNodeCell,
                          with node: FolderBrowserNode
    ) -> DocumentNodeCell {
        cell.nameLabel.text = node.name
        cell.dateLabel.text = dateLabelFormatter.string(from: node.lastModified)
        cell.image.image = node.preview.image

        cell.detailsIndicator.addGestureRecognizer(ZNTapGestureRecognizer { _ in
            let editor = NodeDetailEditor(name: node.name,
                                          onTextfieldEdtitingChanged: {
                                            self.folderVM.rename(node: node, to: $0)
                                            self.dismiss(animated: true, completion: nil)
            },
                                          onDelete: { self.delete(node: node) })

            let optionsVC = UIHostingController(rootView: editor)

            optionsVC.modalPresentationStyle = .popover
            optionsVC.popoverPresentationController?.sourceView = cell.detailsIndicator
            optionsVC.preferredContentSize = CGSize(width: 200,
                                                    height: optionsVC.view.intrinsicContentSize.height)

            self.present(optionsVC, animated: true, completion: nil)
        })

        cell.addGestureRecognizer(ZNTapGestureRecognizer { _ in
            switch node.store {
            case .document(let id):
                self.openNoteEditor(for: id, with: node.name)
            case .directory(let id):
                self.navigateTo(folder: id, with: node.name)
            }
        })

        return cell
    }

    private func delete(node: FolderBrowserNode) {
        let controller = deleteAlertController(for: node)
        self.dismiss(animated: true, completion: nil)
        self.present(controller, animated: true, completion: nil)
    }

    private func navigateTo(folder: DirectoryID, with name: String) {
        guard let destinationViewController =
            DocumentCollectionViewController.from(storyboard: self.storyboard) else { return }
        self.folderVM.subFolderBrowserVM(for: folder, with: name)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in return }, // TODO
                receiveValue: { folderVM in
                    destinationViewController.folderVM = folderVM
                    self.navigationController?.pushViewController(destinationViewController, animated: true)
            })
            .store(in: &cancellables)
    }

    private func openNoteEditor(for note: DocumentID, with name: String) {
        guard let destinationViewController = NoteViewController.from(self.storyboard) else { return }
        destinationViewController.transitionManager = NoteTransitionDelegate()
        destinationViewController
            .previewChangedSubject
            .sink(receiveValue: { image in
                self.folderVM.update(doc: note, preview: image)
                self.collectionView.reloadData()
            })
            .store(in: &cancellables)

        self.folderVM.noteEditorVM(for: note, with: name)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in return }, // TODO
                receiveValue: {
                    destinationViewController.viewModel = $0
                    self.navigationController?.pushViewController(destinationViewController, animated: true)
            })
            .store(in: &cancellables)
    }
}

extension DocumentCollectionViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
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

        guard let node =
            coordinator.items.first?.dragItem.localObject as? FolderBrowserNode else {
                return
        }

        let destination = folderVM.nodes[index]
        switch destination.store {
        case .directory(let id):
            folderVM.move(node: node, to: id)
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
                            let preview = UIImage.from(size: self.view.frame.size).withBackground(color: .white)
                            self.folderVM.createFile(id: ID(UUID()),
                                                     name: "Untitled",
                                                     preview: preview,
                                                     lastModified: Date())
        })
        adderSheet.addAction(
            UIAlertAction(title: "Folder",
                          style: .default) { _ in
                            self.folderVM.createFile(id: ID(UUID()),
                                                     name: "Untitled",
                                                     preview: UIImage.folder(),
                                                     lastModified: Date())
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
