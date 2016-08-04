//
//  Station.swift
//  WunderTemp
//
//  Created by Stephen Brennan on 8/3/16.
//  Copyright © 2016 Stephen Brennan. All rights reserved.
//

import Foundation
import CoreLocation

func computeDistance(p1: CLLocationCoordinate2D, long: CDouble, lat: CDouble) -> Double {
    let dx2 = pow(p1.latitude - lat, 2.0)
    let dy2 = pow(p1.longitude - long, 2.0)
    return pow(dx2 + dy2, 0.5)
}

class Station : CustomStringConvertible {
    let stationRecord : [ String : AnyObject]
    let distance : Double
    let distanceString : String
    
    var tempLabel : String?
    var timeLabel : String?
    var weatherImageData : NSData?
    var processed = false
    
    let feetPer = 0.000003106264313
    let key : String
    
    init(stationRecord : [ String : AnyObject], coord : CLLocationCoordinate2D, key: String ) {
        self.stationRecord = stationRecord
        self.key = key
        
        let lat = stationRecord["lat"] as! Double
        let long = stationRecord["lon"] as! Double
        self.distance = computeDistance(coord, long: long, lat: lat)
        distanceString = String(format: "%.20f", distance)
        //        let neighborhood = ss["neighborhood"] as! String
    }
    
    var urlString : String {
        get {
            return "\(wuAPI)/\(key)/conditions/q/pws:\(stationId).json"
        }
    }
    var stationId : String {
        get {
            return stationRecord["id"] as! String
        }
    }
    
    var neighborhood : String? {
        get {
            return stationRecord["neighborhood"] as? String
        }
    }
    
    var description : String {
        get {
            var locn = "no neighborhood"
            if let n = neighborhood {
                locn = n
            }
            return "\(distanceString) \(locn)"
        }
    }
    
    var location : String {
        get {
            let fmtr = NSNumberFormatter()
            fmtr.numberStyle = NSNumberFormatterStyle.DecimalStyle
            let fmt = fmtr.stringFromNumber(Int(distance / feetPer))
            return "about \(fmt!) feet away"
        }
    }
    
}

