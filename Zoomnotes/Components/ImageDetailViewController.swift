//
//  ImageDetailViewController.swift
//  Zoomnotes
//
//  Created by Berci on 2020. 10. 05..
//  Copyright © 2020. Berci. All rights reserved.
//

import UIKit
import PencilKit

class ImageDetailViewController: UIViewController {
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var canva: PKCanvasView!

    var toolPicker: PKToolPicker!

    override func viewDidLoad() {
        super.viewDidLoad()

        canva.delegate = self

        let window = parent?.view.window
        toolPicker = PKToolPicker.shared(for: window!)

        toolPicker.setVisible(true, forFirstResponder: canva)
        toolPicker.addObserver(canva)
        toolPicker.addObserver(self)

//        updateLayout(for: toolPicker)

        // Do any additional setup after loading the view.
    }
}

extension ImageDetailViewController: PKCanvasViewDelegate {

}

extension ImageDetailViewController: PKToolPickerObserver {

}
