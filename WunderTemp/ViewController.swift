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
    var moved = true
    
    var nextTime = 0.0

    private var foregroundNotification: NSObjectProtocol!

    
    
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var weatherImage: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(timerCallBack), userInfo: nil, repeats: false)
        
        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()
        
        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()

        foregroundNotification = NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillEnterForegroundNotification, object: nil, queue: NSOperationQueue.mainQueue()) {
            [unowned self] notification in
            
            self.updateLocationURL()
        }
    }
    
    deinit {
        // make sure to remove the observer when this view controller is dismissed/deallocated
        
        NSNotificationCenter.defaultCenter().removeObserver(foregroundNotification)
    }


    override func viewDidAppear(animated: Bool) {

        updateLocationURL()
    }
    
    func updateLocationURL() {
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
                
                if (statusCode == 200) {
                    do{
                        
                        let json = try NSJSONSerialization.JSONObjectWithData(data!, options:.AllowFragments)
                        if let d = json["current_observation"] as? [String : AnyObject] {
                            print("current_observation \(d)")
                            if let tempString = d["temperature_string"] as? String {
                                let date = d["local_time_rfc822"] as? String
                                if let loc = d["display_location"] as? [String : AnyObject] {
                                    var descr : String = "None!"
                                    if let n = self.neighborhood {
                                        descr = n
                                    } else if let locName = loc["full"] as? String {
                                        descr = locName
                                    }
                                    
                                    dispatch_async(dispatch_get_main_queue(), {
                                        self.tempLabel.text = "\(descr): \(tempString)"
                                        self.timeLabel.text = date ?? "\(String(NSDate()))"
                                        
                                        if let img_url = d["icon_url"] as? String {
                                            if let url = NSURL(string: img_url) {
                                                if let data = NSData(contentsOfURL: url) {
                                                    self.weatherImage.image = UIImage(data: data)
                                                }
                                            }
                                        }
                                    })
                                    
                                    
                                }
                                return
                            }
                        }
                    } catch {
    
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
    
    func distance(p1: CLLocationCoordinate2D, long: CDouble, lat: CDouble) -> Double {
        let dx2 = pow(p1.latitude - lat, 2.0)
        let dy2 = pow(p1.longitude - long, 2.0)
        return dx2 + dy2
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = manager.location?.coordinate else {
            return
        }
        self.locationManager.stopUpdatingLocation()
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
                                if let station = pws["station"] as? [[ String : AnyObject ]]{
                                    var foundDescr : [ String : AnyObject ]?
                                    var distance = Double.infinity
                                    
                                    
                                    for ss in station {
                                        let lat = ss["lat"] as! Double
                                        let long = ss["lon"] as! Double
                                        let mag = self.distance(coord, long: long, lat: lat)
                                        if mag < distance {
                                            foundDescr = ss
                                            distance = mag
                                        }
                                    }
                                    if let descr = foundDescr {
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
                    self.updateTemp()
                } catch {
                    
                }
            }
        }
        task.resume()
    }
    
}

