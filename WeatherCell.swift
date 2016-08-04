//
//  WeatherCell.swift
//  WunderTemp
//
//  Created by Stephen Brennan on 8/3/16.
//  Copyright © 2016 Stephen Brennan. All rights reserved.
//

import UIKit

class WeatherCell : UITableViewCell {
    @IBOutlet weak var weatherImage : UIImageView!
    @IBOutlet weak var weatherLabel : UILabel!
    @IBOutlet weak var timeLabel : UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    
    func loadItem(weather: String?, time: String?, maybeImage: NSData?, maybeLocation: String?) {
        weatherLabel.text = weather ?? "No Weather"
        timeLabel.text = time ?? "No Time"
        locationLabel.text = maybeLocation ?? ""
        if let image = maybeImage {
            weatherImage.image = UIImage(data: image)
            weatherImage.contentScaleFactor = 0.75
        }
    }
}
