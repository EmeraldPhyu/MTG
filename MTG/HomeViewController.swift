//
//  ViewController.swift
//  MTG
//
//  Created by Emerald on 13/2/18.
//  Copyright © 2018 Emerald. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    @IBAction func aroundyouBtnPressed(_ sender: UIButton) {
        performSegue(withIdentifier: "segueAroundyou", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let targetVC = segue.destination as? MapBaseViewController
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

