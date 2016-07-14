//
//  ViewController.swift
//  WunderTemp
//
//  Created by Stephen Brennan on 7/11/16.
//  Copyright © 2016 Stephen Brennan. All rights reserved.
//

import UIKit
import CoreLocation

let key = "5828c48f756a7400"
let wuAPI = "http://api.wunderground.com/api"
let maxWeather = 5

//"http://api.wunderground.com/api/5828c48f756a7400/conditions/q/pws:\(stationId).json"

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
    
    init(stationRecord : [ String : AnyObject], coord : CLLocationCoordinate2D ) {
        self.stationRecord = stationRecord
        
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
            var fmtr = NSNumberFormatter()
            fmtr.numberStyle = NSNumberFormatterStyle.DecimalStyle
            let fmt = fmtr.stringFromNumber(Int(distance / feetPer))
            return "about \(fmt!) feet away"
        }
    }
    
}

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

class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var stations : [Station]?
    
    let locationManager = CLLocationManager()
    var locValue:CLLocationCoordinate2D?
    
    var nextTime = 0.0

    @IBOutlet weak var weatherTable: UITableView!
    
    private var foregroundNotification: NSObjectProtocol!

    
    
//    @IBOutlet weak var tempLabel: UILabel!
//    @IBOutlet weak var timeLabel: UILabel!
//    @IBOutlet weak var weatherImage: UIImageView!
    
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
    
//    func timerCallBack() {
//        if let _ = self.stations {
//            let now = NSDate().timeIntervalSince1970
//            if now > self.nextTime {
//                updateTemp()
//                nextTime = now + 60
//            }
//        }
//    }
    
    
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
//                                print(pws)
                                if let station = pws["station"] as? [[ String : AnyObject ]]{
                                    var newStations = [Station]()
                                    
                                    
                                    for ss in station {
                                        newStations.append(Station(stationRecord: ss, coord: coord))
                                    }
                                    self.stations = newStations.sort{ (e1, e2) -> Bool in
                                        return e1.distance < e2.distance
                                    }
                                    
                                    for ss in self.stations! {
                                        print("\(ss)")
                                    }
                                    
//                                    if let descr = foundDescr {
//                                        if let stationId = descr["id"] as? String {
//                                            self.stationUrl = "http://api.wunderground.com/api/5828c48f756a7400/conditions/q/pws:\(stationId).json"
//                                        }
//                                        
//                                        if let neighborhood = descr["neighborhood"] as? String {
//                                            self.neighborhood = neighborhood
//                                        } else {
//                                            self.neighborhood = nil
//                                        }
//                                        
//                                    }
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
}

