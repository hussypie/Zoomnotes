//
//  NodeDetailEditor.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 09. 18..
//  Copyright © 2020. Berci. All rights reserved.
//

import SwiftUI

struct NodeDetailEditor: View {
    private let onDelete: () -> Void
    @Binding var name: String

    init(name: Binding<String>, onDelete: @escaping () -> Void) {
        self._name = name
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Divider()
            Button(action: self.onDelete,
                   label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
            }).foregroundColor(.red)
        }
        .padding()
    }
}

struct NodeDetailEditor_Previews: PreviewProvider {
    static var previews: some View {
        NodeDetailEditor(name: .constant("Title"), onDelete: { })
    }
}
