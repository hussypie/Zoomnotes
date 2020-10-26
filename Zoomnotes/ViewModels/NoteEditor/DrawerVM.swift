//
//  DrawerVM.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 26..
//  Copyright © 2020. Berci. All rights reserved.
//

import Foundation
import Combine

class DrawerVM: ObservableObject {
    @Published var nodes: [NoteChildVM]

    init(nodes: [NoteChildVM]) { self.nodes = nodes }
}
