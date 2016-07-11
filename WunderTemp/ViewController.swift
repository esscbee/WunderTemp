//
//  ViewController.swift
//  WunderTemp
//
//  Created by Stephen Brennan on 7/11/16.
//  Copyright © 2016 Stephen Brennan. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    let locationManager = CLLocationManager()
    var locValue:CLLocationCoordinate2D?
    var stationUrl : String?
    var neighborhood: String?
    
    var nextTime = 0.0

    
    
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(timerCallBack), userInfo: nil, repeats: true)
        
        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()
        
        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
    }
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateTemp() {
        if let urlString = stationUrl {
            let requestURL: NSURL = NSURL(string: urlString)!
            let urlRequest: NSMutableURLRequest = NSMutableURLRequest(URL: requestURL)
            let session = NSURLSession.sharedSession()
            let task = session.dataTaskWithRequest(urlRequest) {
                (data, response, error) -> Void in
                
                let httpResponse = response as! NSHTTPURLResponse
                let statusCode = httpResponse.statusCode
                var statusText = "searching"
                
                if (statusCode == 200) {
                    do{
                        
                        let json = try NSJSONSerialization.JSONObjectWithData(data!, options:.AllowFragments)
                        if let d = json["current_observation"] as? [String : AnyObject] {
                            if let tempString = d["temperature_string"] as? String {
                                if let loc = d["display_location"] as? [String : AnyObject] {
                                    var descr : String = "None!"
                                    if let n = self.neighborhood {
                                        descr = n
                                    } else if let locName = loc["full"] as? String {
                                        descr = locName
                                    }
                                    
                                    dispatch_async(dispatch_get_main_queue(), {
                                        self.tempLabel.text = "\(descr): \(tempString)"
                                        self.timeLabel.text = "\(String(NSDate()))"
                                    })
                                    
                                    
                                }
                                return
                            }
                        }
                    } catch {
                        statusText = "JSON error \(String(NSDate()))"
                    }
                } else {
                    self.tempLabel.text = "status: \(statusCode)"
                }
            }
            
            task.resume()
        }
    }
    
    func timerCallBack() {
        if let _ = self.stationUrl {
            let now = NSDate().timeIntervalSince1970
            if now > self.nextTime {
                updateTemp()
                nextTime = now + 60
            }
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = manager.location?.coordinate else {
            return
        }
        if let oldLoc = self.locValue {
            if oldLoc.latitude == coord.latitude && oldLoc.longitude == coord.longitude {
                return
            }
        }
        self.locValue = coord
       
        let requestURL: NSURL = NSURL(string: "http://api.wunderground.com/api/5828c48f756a7400/geolookup/q/\(coord.latitude),\(coord.longitude).json")!
        let urlRequest: NSMutableURLRequest = NSMutableURLRequest(URL: requestURL)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(urlRequest) {
            (data, response, error) -> Void in
            
            let httpResponse = response as! NSHTTPURLResponse
            let statusCode = httpResponse.statusCode
            
            if (statusCode == 200) {
                do{
                    
                    let json = try NSJSONSerialization.JSONObjectWithData(data!, options:.AllowFragments)
//                    print(json)
                    if let location = json["location"] as? [String : AnyObject] {
                        if let nearby = location["nearby_weather_stations"]  as? [String : AnyObject] {
//                            print(nearby)
                            if let pws = nearby["pws"] as? [String : AnyObject] {
                                print(pws)
                                if let station = pws["station"] {
                                    if let descr = station[0] as? [String : AnyObject ] {
                                        if let stationId = descr["id"] as? String {
                                            self.stationUrl = "http://api.wunderground.com/api/5828c48f756a7400/conditions/q/pws:\(stationId).json"
                                        }
                                        
                                        if let neighborhood = descr["neighborhood"] as? String {
                                            self.neighborhood = neighborhood
                                        } else {
                                            self.neighborhood = nil
                                        }
                                    }
                                }
                            }
                            
                        }
                    }
                } catch {
                    
                }
            }
        }
        task.resume()
    }
    
}

