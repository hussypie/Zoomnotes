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

class DocumentCollectionViewController: UIViewController {
    enum Section {
        case files
    }

    var folderVM: FolderBrowserViewModel!
    var logger: LoggerProtocol!

    lazy var dataSource = makeDataSource()
    lazy var collectionView = makeCollectionView()

    var cancellables: Set<AnyCancellable> = []

    func deleteAlertController(for node: FolderBrowserNode) -> UIAlertController {
        let alert = UIAlertController(
            title: "Delete \(node.name)?",
            message: "Are you sure to delete \(node.name)?",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .default,
                handler: { [unowned self] _ in self.logger.info("Delete node cancelled") }
            )
        )

        alert.addAction(
            UIAlertAction(
                title: "Delete",
                style: .destructive,
                handler: { [unowned self] _ in
                    self.folderVM.delete(node: node)
                        .sink(receiveDone: { },
                              receiveError: { [unowned self] in
                                self.logger.warning("Delete node failed (error: \($0.localizedDescription)")
                            },
                              receiveValue: { [unowned self] _ in
                                self.logger.info("Deleted node (id: \(node.id))")

                        })
                        .store(in: &self.cancellables)
            }))
        return alert
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.collectionView.register(DocumentNodeCell.self,
                                     forCellWithReuseIdentifier: DocumentNodeCell.identifier)

        self.collectionView.dataSource = dataSource

        self.collectionView.backgroundColor = .systemBackground

        _ = self.view.add(collectionView) { [unowned self] make in
            make.top.equalTo(self.view)
            make.leading.equalTo(self.view)
            make.trailing.equalTo(self.view)
            make.bottom.equalTo(self.view)
        }

        collectionView.dragDelegate = self
        collectionView.dropDelegate = self

        self.navigationItem.leftItemsSupplementBackButton = true

        self.setupVM()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }

    private func nodesDidLoad(_ conversions: [FolderBrowserNode]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, FolderBrowserNode>()
        snapshot.appendSections([.files])
        snapshot.appendItems(conversions, toSection: .files)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func setupVM() {
        // swiftlint:disable:next force_cast
        let appdelegate = (UIApplication.shared.delegate as! AppDelegate)
        self.logger = appdelegate.logger

        self.logger.info("Initializing folder VM")
        Just(folderVM)
            .eraseToAnyPublisher()
            .setFailureType(to: Error.self)
            .flatMap { [unowned self] vm -> AnyPublisher<FolderBrowserViewModel, Error> in
                if vm != nil {
                    self.logger.info("Initializing with already existing view model")
                    return Just(vm!)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()

                }
                let directoryAccess = DirectoryAccessImpl(access: appdelegate.access,
                                                          logger: appdelegate.logger)

                appdelegate.logger.info("Creating root view model")

                return FolderBrowserViewModel
                    .root(defaults: UserDefaults.standard, access: directoryAccess)
        }
        .sink(receiveDone: { [unowned self] in self.logger.info("View model created") },
              receiveError: { [unowned self] error in
                self.logger.error("Cannot create view controller, reason: \(error.localizedDescription)")
                fatalError(error.localizedDescription)
            },
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

                folderVM
                    .$nodes
                    .sink(receiveValue: { [unowned self] nodes in
                        if nodes.isEmpty {
                            self.collectionView.setEmptyMessage("Tap + to add file")
                        } else {
                            self.collectionView.unsetEmptyMessage()
                        }
                        self.nodesDidLoad(nodes)
                    })
                    .store(in: &self.cancellables)

        })
            .store(in: &cancellables)
    }

    func delete(node: FolderBrowserNode) {
        self.logger.info("Presenting delete dialog")
        let controller = deleteAlertController(for: node)
        self.dismiss(animated: true, completion: nil)
        self.present(controller, animated: true, completion: nil)
    }

    func navigateTo(folder: DirectoryID, with name: String) {
        guard let destinationViewController =
            DocumentCollectionViewController.from(self.storyboard) else { return }
        self.folderVM.subFolderBrowserVM(for: folder, with: name)
            .receive(on: DispatchQueue.main)
            .sink(receiveDone: { },
                  receiveError: { [unowned self] error in
                    self.logger.warning("Cannot create subfolder view model, reason: \(error.localizedDescription)")
                },
                  receiveValue: { folderVM in
                    destinationViewController.folderVM = folderVM
                    self.logger.warning("Navigating to subfolder (id: \(folder))")
                    self.navigationController?.pushViewController(destinationViewController, animated: true)
            })
            .store(in: &cancellables)
    }

    func openNoteEditor(node: FolderBrowserNode, for note: DocumentID, with name: String) {
        guard let destinationViewController = NoteViewController.from(self.storyboard) else { return }
        destinationViewController.transitionManager = NoteTransitionDelegate()
        destinationViewController
            .previewChangedSubject
            .sink(receiveValue: { [unowned self] image in
                self.folderVM
                    .update(doc: note, preview: image)
                    .sink(receiveDone: { },
                          receiveError: { [unowned self] error in
                            self.logger.warning("Cannot update note preview, reason: \(error.localizedDescription)")
                        },
                          receiveValue: { _ in
                            node.preview = CodableImage(wrapping: image)
                            self.logger.info("Updated preview image of node (id: \(node.id))")
                    })
                    .store(in: &self.cancellables)
            })
            .store(in: &cancellables)

        self.folderVM.noteEditorVM(for: note, with: name)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveDone: { },
                receiveError: { [unowned self] error in
                    self.logger.warning("Cannot create note view controller, reason: \(error.localizedDescription)")
                },
                receiveValue: { vm in
                    destinationViewController.viewModel = vm
                    destinationViewController.onUnload = { vm?.emptyTrash() }
                    self.navigationController?.pushViewController(destinationViewController, animated: true)
                    self.logger.info("Navigating to note editor (id: \(note))")
            })
            .store(in: &cancellables)
    }
}

extension DocumentCollectionViewController {
    @IBAction func onSettingsButtonClick(_ sender: Any) {
        let settingsController = UIHostingController(rootView: SettingsView())
        self.logger.info("Navigating to settings view")
        self.navigationController?.pushViewController(settingsController, animated: true)
    }

    @IBAction func onAddNewButtonClicked(_ sender: Any) {
        guard let addButton = sender as? UIBarButtonItem else { return }
        let adderSheet = UIAlertController(title: nil,
                                           message: "Add a note or a folder",
                                           preferredStyle: .actionSheet)
        adderSheet.addAction(
            UIAlertAction(
                title: "Note",
                style: .default
            ) { [unowned self] _ in
                let preview = UIImage.from(size: self.view.frame.size).withBackground(color: .white)
                self.folderVM
                    .createFile(id: ID(UUID()), name: "Untitled", preview: preview, lastModified: Date())
                .sink(receiveDone: { },
                      receiveError: { [unowned self] error in
                      self.logger.warning("Could not create file, reason: \(error.localizedDescription)")
                    },
                      receiveValue: { [unowned self] in self.logger.info("New file created") })
                    .store(in: &self.cancellables)
        })
        adderSheet.addAction(
            UIAlertAction(
                title: "Folder",
                style: .default
            ) { [unowned self] _ in
                self.folderVM
                    .createFolder(id: ID(UUID()), created: Date(), name: "Untitled")
                    .sink(receiveDone: { },
                          receiveError: { [unowned self] error in
                            self.logger.warning("Could not create folder, reason: \(error.localizedDescription)")
                        },
                          receiveValue: { [unowned self] in self.logger.info("New folder created") })
                    .store(in: &self.cancellables)

        })

        adderSheet.popoverPresentationController?.barButtonItem = addButton

        self.logger.info("Presenting node adding sheet")
        self.present(adderSheet, animated: true, completion: nil)
    }
}
