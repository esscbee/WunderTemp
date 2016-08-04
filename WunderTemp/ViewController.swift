//
//  ViewController.swift
//  WunderTemp
//
//  Created by Stephen Brennan on 7/11/16.
//  Copyright © 2016 Stephen Brennan. All rights reserved.
//

import UIKit
import CoreLocation

let wuAPI = "http://api.wunderground.com/api"
let maxWeather = 5


class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDelegate, UITableViewDataSource {
    var key : String?
    
    var stations : [Station]?
    
    let locationManager = CLLocationManager()
    var locValue:CLLocationCoordinate2D?
    
    var nextTime = 0.0

    @IBOutlet weak var weatherTable: UITableView!
    
    private var foregroundNotification: NSObjectProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()
    
//        
//        // Ask for Authorisation from the User.
//        self.locationManager.requestAlwaysAuthorization()
        
        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()

        foregroundNotification = NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillEnterForegroundNotification, object: nil, queue: NSOperationQueue.mainQueue()) {
            [unowned self] notification in
            
            self.updateLocationURL()
        }
        
        let nib = UINib(nibName: "WeatherCell", bundle: nil)
        
//        self.weatherTable.registerClass(UITableViewCell.self)
        self.weatherTable.registerNib(nib, forCellReuseIdentifier: "weatherCell")

    }
    
    deinit {
        // make sure to remove the observer when this view controller is dismissed/deallocated
        
        NSNotificationCenter.defaultCenter().removeObserver(foregroundNotification)
    }


    override func viewDidAppear(animated: Bool) {
        
        updateLocationURL()
    }
    
    func updateLocationURL() {
        
        guard let _ = key else {
            showSettings(self)
            return
        }
        
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
        if let ss = stations {
            if ss.isEmpty {
                return
            }
            for theStation in ss[0..<maxWeather] {
                if theStation.processed {
                    continue
                }
                theStation.processed = true
                let requestURL: NSURL = NSURL(string: theStation.urlString)!
                let urlRequest: NSMutableURLRequest = NSMutableURLRequest(URL: requestURL)
                let session = NSURLSession.sharedSession()
                let task = session.dataTaskWithRequest(urlRequest) {
                    (data, response, error) -> Void in
                    
                    print("Get Weather \(theStation.description)")
                    
                    let httpResponse = response as! NSHTTPURLResponse
                    let statusCode = httpResponse.statusCode
                    
                    if (statusCode == 200) {
                        do{
                            let json = try NSJSONSerialization.JSONObjectWithData(data!, options:.AllowFragments)
                            if let d = json["current_observation"] as? [String : AnyObject] {
                                //                            print("current_observation \(d)")
                                if let tempString = d["temperature_string"] as? String {
                                    let date = d["local_time_rfc822"] as? String
                                    if let loc = d["display_location"] as? [String : AnyObject] {
                                        var descr : String = "None!"
                                        if let n = theStation.neighborhood {
                                            descr = n
                                        } else if let locName = loc["full"] as? String {
                                            descr = locName
                                        }
                                        
                                        theStation.tempLabel = "\(descr): \(tempString)"
                                        theStation.timeLabel = date ?? "\(String(NSDate()))"
                                        if let img_url = d["icon_url"] as? String {
                                            if let url = NSURL(string: img_url) {
                                                if let data = NSData(contentsOfURL: url) {
                                                    theStation.weatherImageData = data
                                                }
                                            }
                                        }
                                        dispatch_async(dispatch_get_main_queue(), {
                                            self.weatherTable.reloadData()
                                        })
                                        
                                    }
                                    return
                                }
                            }
                        } catch  {
                            print("Exception!")
                        }
                    } else {
                        print("status: \(statusCode)")
                    }
                }
                
                task.resume()
            }
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coord = manager.location?.coordinate else {
            return
        }
        let now = NSDate().timeIntervalSince1970
        if now < nextTime {
            return
        }
        nextTime = now + 90
        self.locationManager.stopUpdatingLocation()
        let urlString = "http://api.wunderground.com/api/\(key!)/geolookup/q/\(coord.latitude),\(coord.longitude).json"
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
                    //                    print(json)
                    if let location = json["location"] as? [String : AnyObject] {
                        if let nearby = location["nearby_weather_stations"]  as? [String : AnyObject] {
                            //                            print(nearby)
                            if let pws = nearby["pws"] as? [String : AnyObject] {
//                                print(pws)
                                if let station = pws["station"] as? [[ String : AnyObject ]]{
                                    var newStations = [Station]()
                                    
                                    
                                    for ss in station {
                                        newStations.append(Station(stationRecord: ss, coord: coord, key: self.key!))
                                    }
                                    self.stations = newStations.sort{ (e1, e2) -> Bool in
                                        return e1.distance < e2.distance
                                    }
                                    
                                    for ss in self.stations! {
                                        print("\(ss)")
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
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let ret = min(stations?.count ?? 0, maxWeather)
        print("tableView numberOfRowsInSection: \(ret)")
        return ret
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = self.weatherTable.dequeueReusableCellWithIdentifier("weatherCell") as! WeatherCell
        if let ss = stations?[indexPath.row] {
            cell.loadItem(ss.tempLabel, time: ss.timeLabel, maybeImage: ss.weatherImageData, maybeLocation: ss.location)
            
        }
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        print("didSelectRowAtIndexPath: \(indexPath)")
        
    }
    
    func setWunderKey(key : String?) {
        if let k = key {
            self.key = k
        }
    }

    @IBAction func showSettings(sender: AnyObject) {
        
        performSegueWithIdentifier("Settings", sender: self)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let settings = segue.destinationViewController as? SettingsViewController {
            if let k = key {
                settings.key = k
            }
        }
    }
    
    @IBAction func commitSettings(sender : UIStoryboardSegue) {
        if let settings = sender.sourceViewController as? SettingsViewController {
            setWunderKey(settings.getKey())
            updateLocationURL()
        }
        
    }
    @IBAction func cancelSettings(sender : UIStoryboardSegue) {
        
    }
}

