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
    private let onTextfieldEdtitingChanged: (String) -> Void
    var name: String

    init(name: String,
         onTextfieldEdtitingChanged: @escaping (String) -> Void,
         onDelete: @escaping () -> Void
    ) {
        self.name = name
        self.onTextfieldEdtitingChanged = onTextfieldEdtitingChanged
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading) {
            OkayableTextfield("Title", text: self.name, onCommit: self.onTextfieldEdtitingChanged)
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
        NodeDetailEditor(name: "Title",
                         onTextfieldEdtitingChanged: { print($0) },
                         onDelete: { })
    }
}
