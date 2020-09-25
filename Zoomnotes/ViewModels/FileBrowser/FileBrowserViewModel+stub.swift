//
//  FileBrowserViewModel+stub.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 25..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation

extension FolderBrowserViewModel {
    static var stub: FolderBrowserViewModel {
        let access = CoreDataAccess(directory: DirectoryAccessMock(),
                                    file: DocumentAccessMock())

        return FolderBrowserViewModel(directoryId: UUID(),
                                      name: "Documents",
                                      nodes: [],
                                      access: access)
    }

    static func stub(nodes: [FolderBrowserViewModel.Node]) -> FolderBrowserViewModel {
        let access = CoreDataAccess(directory: DirectoryAccessMock(),
                                    file: DocumentAccessMock())

        return FolderBrowserViewModel(directoryId: UUID(),
                                      name: "Documents",
                                      nodes: nodes,
                                      access: access)
    }
}
