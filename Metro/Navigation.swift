//Handles all of the data from the location manager

import _math
import unistd
import Combine
import Foundation
import UserNotifications

class Navigation: ObservableObject{
    
    //distance to alert notification to pop up in miles
    private let alertDistance: Double = 0.75
    private let arrivedDistance: Double = 0.25
    
    private let alertMotionDistance: Double = 0.45
    private let arrivedMotionDistance: Double = 0.0
    
    //coordinates is the current coordinates of the device
    public var coordinates:(lat: Double, lon: Double)
    
    //path we need to take
    var path: [Station]
    //station to switch at and the train to get there for values
    var stationsToSwitch: [Station:String]
    var orderOfStationSwitch: [Station]
    
    //list of all coords of every station
    var listOfCoords: [String : (lat: Double, lon: Double)]
    
    //singleton
    static var shared = Navigation()
    
    //String variables to be updated and used in ContentView
    
    @Published var nextDestinationStatus: String = "Unknown Destination" //the status of the next station in the path
    @Published var distanceFromNextDestination: String = "∞ miles away" //distance to next station
    @Published var travelingSpeed: String = "Traveling at ∞ mph" //current traveling speed
    @Published var nextStations: String = "Path not found" //displays the next 5 stations
    @Published var switchingStationText: String = "" //the text that displays the next switching stations
    @Published var stopsAwayFromDestination: String = "∞ stops away from Unknown" //stops away from the end destination
    
    //for alerts
    @Published var alertTitle: String = ""
    @Published var alertBody: String = ""
    
    //for connection status
    @Published var connectionStatus: String = "GPS"
    
    //for motion backup calculations
    
    //intially the currrent cords like when the app just started
    private var distanceToNext: Double = 9999
    
    //constuctor
    private init(coords: (lat: Double, lon: Double), path: [Station], stationsToSwitch: [Station:String], orderOfStationSwitch:[Station]){
        coordinates = coords
        self.path = path
        self.stationsToSwitch = stationsToSwitch
        listOfCoords = [:]
        self.orderOfStationSwitch = orderOfStationSwitch
        
        populateStationCoords()
        //request notification permission
        requestNotificationPermission()
        
        let firstStation: Station = path.first!
        
        self.distanceToNext = calculateDistance(lat: listOfCoords[firstStation.name]!.lat, lon: listOfCoords[firstStation.name]!.lon)
    }
    
    
    //default constructor
    private init(){
        coordinates = (0,0)
        self.path = []
        self.stationsToSwitch = [:]
        listOfCoords = [:]
        self.orderOfStationSwitch = []
        
        populateStationCoords()
        requestNotificationPermission()
    }
    
    //sets the fields string to the according data
    public func returnStatus(){
        //reset alerts
        var newAlertTitle = ""
        var newAlertBody = ""
        
        //update speed
        travelingSpeed = "(GPS) Traveling at " + String(Navigation.convertSpeed(speed:LocationManager.shared.gpsSpeed)) + " mph\n(Motion) Traveling at " + String(Navigation.convertSpeed(speed: LocationManager.shared.motionSpeed)) + " mph"
        
        print("GPS " + String(Navigation.convertSpeed(speed:LocationManager.shared.gpsSpeed)))
        print("Motion " + String(Navigation.convertSpeed(speed: LocationManager.shared.motionSpeed)))
        
        if (path.isEmpty){
            nextDestinationStatus = "Destination Reached!"
            return
        }
        
        //next station in path
        let stationDestination: Station = path.first!
        let distance: Double = calculateDistance(lat: listOfCoords[stationDestination.name]!.lat, lon: listOfCoords[stationDestination.name]!.lon)
        //print(distance)
        
        
        //arriving at the station
        if (distance <= arrivedDistance || distanceToNext - LocationManager.shared.motionDistanceTraveled / 1609 <= arrivedMotionDistance){
            nextDestinationStatus = "Arriving at \(stationDestination.name) Station"
            
            
            //check if switching train list is empty meaning only need to say how many stops till destination
            if (orderOfStationSwitch.isEmpty){
                newAlertTitle = "Arrived at \(stationDestination.name) Station"
                newAlertBody = "\(numberOfStopsAway(name: path.last!.name)) stops away from \(path.last!.name)"
            }
            
            //check if it is a switching train time, greater than 1 means you actually need to switch
            else if (stationsToSwitch.keys.contains(stationDestination) && stationsToSwitch.count > 1){
                newAlertTitle = "Arrived at \(stationDestination.name) Station"
                newAlertBody = "Switch to "  + stationsToSwitch[orderOfStationSwitch.first!]!
                
                //notification to switch to different trai
                
                nextDestinationStatus += "\n!!Switch to" + String(stationsToSwitch[orderOfStationSwitch[1]]!) + "!!"
                
                //remove train swap
                let indexOfSwap = stationsToSwitch.index(forKey: stationDestination)!
                stationsToSwitch.remove(at: indexOfSwap)
                orderOfStationSwitch.removeFirst()
            }
            
            //notification for when you still need to swtich trains later so the body should say that
            else{
                newAlertTitle = "Arrived at \(stationDestination.name) Station"
                newAlertBody = "Switching Trains at " + orderOfStationSwitch.first!.name + " with \(numberOfStopsAway(name: orderOfStationSwitch.first!.name)) stops away!"
            }
            
            //remove the train from path
            let first = path.removeFirst()
            if let second = path.first{
                distanceToNext = calculateDistance(lat1: listOfCoords[first.name]!.lat, lon1: listOfCoords[first.name]!.lon, lat2: listOfCoords[second.name]!.lat, lon2: listOfCoords[second.name]!.lon)
                LocationManager.shared.resetValuesForNextTrip()
            }
        }
        //about to arrive at the station
        else if (distance <= alertDistance || distanceToNext - LocationManager.shared.motionDistanceTraveled / 1609 <= alertMotionDistance){
            nextDestinationStatus = "About to Arrive at \(stationDestination.name) Station"
            
            if orderOfStationSwitch.first == stationDestination {
                newAlertTitle = "About to arrive at \(stationDestination.name) Station"
                newAlertBody = "Get ready to switch to " + stationsToSwitch[orderOfStationSwitch.first!]!
            }
        }
        
        //not arriving soon
        else{
            nextDestinationStatus = "Going to \(stationDestination.name) Station"
            
            //check if the closest station is in the path. If it is remove the list until its reached
            let closestStation:String = findClosestStation()
            if (containsName(name:closestStation) && path.first!.name != closestStation){
                while path.first!.name != closestStation{
                    
                    if (orderOfStationSwitch.first == path.first){
                        orderOfStationSwitch.removeFirst()
                    }
                    if (stationsToSwitch[path.first!] != nil){
                        stationsToSwitch.removeValue(forKey: path.first!)
                    }
                    print("Found closer station")
                    
                    let first = path.removeFirst()
                    if let second = path.first{
                        distanceToNext = calculateDistance(lat: listOfCoords[second.name]!.lat, lon: listOfCoords[second.name]!.lon)
                        //distanceToNext = calculateDistance(lat1: listOfCoords[first.name]!.lat, lon1: listOfCoords[first.name]!.lon, lat2: listOfCoords[second.name]!.lat, lon2: listOfCoords[second.name]!.lon)
                        LocationManager.shared.resetValuesForNextTrip()
                    }
                }
                newAlertTitle = "Closer station found!"
                newAlertBody = "Changing next Station to " + path.first!.name
            }
            
        }
        
        if (path.isEmpty){
            nextDestinationStatus = "Destination Reached!"
            return
        }
        
        
        //show distance and speed
        let distance2Deci: Double = Double(round(distance * 1000)/1000)
        
        distanceFromNextDestination = "(GPS) \(distance2Deci) miles away\n(Motion) \(distanceToNext - (LocationManager.shared.motionDistanceTraveled) / 1609) miles away"
        
        nextStations = getNextStations(count: 5)
        
        switchingStationText = ""
        for i in orderOfStationSwitch {
            switchingStationText += "\nTake the " + String(stationsToSwitch[i]!) + " until \(i) Station\n"
            
            if i != orderOfStationSwitch.last{
                switchingStationText += "\(numberOfStopsAway(name: i.name)) stops away\n"
            }
        }
        stopsAwayFromDestination = "\(numberOfStopsAway(name: path.last!.name)) stops away from \(path.last!.name)"
        
        if (!newAlertBody.isEmpty && !newAlertTitle.isEmpty){
            scheduleNotification(title: alertTitle, body: alertBody)
            triggerAlert(title: newAlertTitle, body: newAlertBody)
        }
    }
    
    // Method to trigger alert
    func triggerAlert(title: String, body: String) {
        self.alertTitle = title
        self.alertBody = body
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.alertTitle = ""
            self.alertBody = ""
        }
    }
    
    // Request notification permissions
    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            if granted {
                print("Notification permission granted.")
            } else {
                print("Notification permission denied.")
            }
        }
    }
    // Schedule a notification
    private func scheduleNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }
    
    // method to return a string that contains the next count number of stations in the path
    private func getNextStations(count: Int) -> String{
        if path.count == 0{
            return ""
        }
        if path.count == 1{
            return " -> " + path.last!.name
        }
        
        
        var res: String = ""
        for i in 0..<count{
            //check for last
            if path[i] != path.last{
                res += path[i].name + " -> "
            }
            else{
                break
            }
        }
        return res + " ... -> " + path.last!.name
    }
    
    //method that returns the number of stops the parameter name is away
    private func numberOfStopsAway(name: String) -> Int{
        for i in 0..<path.count{
            if (path[i].name == name){
                return i
            }
        }
        return -1
    }
    
    private func containsName(name: String) -> Bool {
        for i in path{
            if (i.name == name){
                return true
            }
        }
        return false
    }
    
    // method that initializes the coords map
    private func populateStationCoords(){
        let stationNames: [String] = ["Medical Center", "L'Enfant Plaza", "Pentagon City", "Fort Totten", "Federal Triangle", "Tysons", "Ashburn", "Metro Center", "Brookland-CUA", "Huntington", "Loudoun Gateway", "Rhode Island Ave", "Crystal City", "Smithsonian", "Vienna", "Cleveland Park", "King St-Old Town", "Rockville", "Morgan Blvd", "NoMa-Gallaudet U", "Archives", "Farragut North", "Rosslyn", "Hyattsville Crossing", "Arlington Cemetery", "Judiciary Sq", "Capitol Heights", "Court House", "Addison Rd", "Tenleytown-AU", "Clarendon", "New Carrollton", "Georgia Ave-Petworth", "Dunn Loring", "Capitol South", "Van Dorn St", "Wheaton", "Navy Yard-Ballpark", "Southern Ave", "Shaw-Howard U", "Mt Vernon Sq", "Franconia-Springfield", "Shady Grove", "McPherson Sq", "Braddock Rd", "Union Station", "Branch Ave", "Van Ness-UDC", "U St", "Grosvenor-Strathmore", "Pentagon", "West Falls Church", "Deanwood", "Woodley Park", "Gallery Place", "Farragut West", "McLean", "Spring Hill", "College Park-U of Md", "Anacostia", "Herndon", "Minnesota Ave", "Twinbrook", "Columbia Heights", "Waterfront", "West Hyattsville", "Potomac Ave", "Suitland", "Eastern Market", "Eisenhower Ave", "Wiehle-Reston East", "Washington Dulles International Airport", "Dupont Circle", "Naylor Rd", "Federal Center SW", "Takoma", "Greensboro", "Ballston-MU", "Virginia Sq-GMU", "Reston Town Center", "Innovation Center", "Congress Heights", "Friendship Heights", "Stadium-Armory", "Bethesda", "East Falls Church", "North Bethesda", "Downtown Largo", "Forest Glen", "Greenbelt", "Foggy Bottom-GWU", "Cheverly", "Benning Rd", "Silver Spring", "Ronald Reagan Washington National Airport", "Glenmont", "Potomac Yard", "Landover"]
        let lat: [Double] = [38.9999040348105, 38.8852329151742, 38.8631861665911, 38.9527449446828, 38.9054145432983, 38.92062541, 39.0385337881606, 38.9486339070986, 38.9341261171923, 38.8123285636299, 38.9988406324717, 38.9571536104159, 38.8652581531673, 38.9315434967743, 38.8772904613526, 38.9370197646839, 38.8079096742073, 39.0850954372657, 38.8946001031349, 38.9081104233333, 38.8939100251248, 38.9027526763505, 38.8969109014718, 38.9652654213752, 38.8845906102298, 38.8972908308064, 38.88926421883, 38.8911692180553, 38.8867599006369, 38.9480984948482, 38.8871162215439, 38.9480390730306, 38.9369338329937, 38.8836559537699, 38.8856073032137, 38.7993121932248, 39.0387320447658, 38.8766885832458, 38.8406386228881, 38.9144414999537, 38.9053473879397, 38.7665141042986, 39.1200109213966, 38.9011438032542, 38.8140361242506, 38.8978536538741, 38.8270301377964, 38.9445071417114, 38.9168383099061, 39.0290920130468, 38.8692364807122, 38.900803224883, 38.9081961477888, 38.9245272528744, 38.8996523862757, 38.9014693551139, 38.9244071824284, 38.9292575730994, 38.9783009574312, 38.8622173333835, 38.9528298155758, 38.8991301747232, 39.0624359792636, 38.9289046081975, 38.8769470083552, 38.955535623103, 38.8808451947431, 38.8446730143789, 38.8842690722674, 38.8003560903306, 38.9477006139994, 38.955806122237, 38.9109854896693, 38.8511151981287, 38.8848705032639, 38.9756136212798, 38.9208573530573, 38.8820276927622, 38.8829446397369, 38.9527618282836, 38.9607798990423, 38.8449900165164, 38.9609419975369, 38.8883247657428, 38.9842091816392, 38.8852340098053, 39.0475639131034, 38.9005650590275, 39.0154770527377, 39.0109246010837, 38.9008570954997, 38.9161878852812, 38.890386391095, 38.9937406445385, 38.8533678785544, 39.061806258531, 38.8332076145698, 38.9335497543254]
        let lon: [Double] = [-77.0969550826986, -77.0220074509648, -77.0593491577617, -77.002273440667, -77.0324506930453, -77.22230377, -77.4950700994524, -77.0311393454648, -76.9946458753342, -77.0713412677288, -77.4610865892251, -76.9957671656239, -77.0507071175625, -77.0340424274091, -77.2712445845882, -77.0591278906755, -77.0600935447166, -77.1465914519666, -76.8686163901561, -77.0035685367198, -77.0222257936163, -77.0391827339415, -77.0719817195572, -76.9563498589526, -77.0636440530811, -77.0175831644984, -76.9132170614894, -77.0850242739564, -76.8955591216995, -77.079340382638, -77.0952217267788, -76.8718733630786, -77.0241918801316, -77.2272830713121, -77.0060684028927, -77.1292476977627, -77.0502877137905, -77.0044410530034, -76.9756082411432, -77.0217670524476, -77.0222746001919, -77.1679930059186, -77.1647442828712, -77.032235193158, -77.0538091065013, -77.0071012016401, -76.9123635771038, -77.0640365499331, -77.0291197323521, -77.1038101345986, -77.0537967311425, -77.1890743502983, -76.935201364994, -77.0523964808301, -77.0218047957305, -77.042033029672, -77.2103656441887, -77.2419303233554, -76.9283410233276, -76.9951963431567, -77.3851858702751, -76.9467838842373, -77.1209520745432, -77.0324733571256, -77.0175834367963, -76.9693004027689, -76.9852151477807, -76.9321955658757, -76.9958484228109, -77.071161682272, -77.3399273056313, -77.4481932973322, -77.0446625268452, -76.9566222026531, -77.0155822681604, -77.0179193699952, -77.2337878549752, -77.1114297951729, -77.1033572269599, -77.3601886939728, -77.4152980000868, -76.9877328961392, -77.0860700558651, -76.9770834161822, -77.0940944294287, -77.1567309405186, -77.1126625405172, -76.8445790839307, -77.0429651448069, -76.9113324675534, -77.0504800910523, -76.9163006463658, -76.9374820642137, -77.0312021587994, -77.0440303232429, -77.0535981112953, -77.0465455822236, -76.8913540521034,]

        for i in 0..<stationNames.count{
            listOfCoords[stationNames[i]] = (lat[i],lon[i])
        }
    }
    
    // method that returns the closest station to the users current location
    private func findClosestStation() -> String{
        var minDistance: Double = Double.greatestFiniteMagnitude
        var minStation: String = "Error"
        
        for i in listOfCoords.keys{
            if (calculateDistance(lat: listOfCoords[i]!.lat, lon: listOfCoords[i]!.lon) < minDistance){
                minDistance = calculateDistance(lat: listOfCoords[i]!.lat, lon: listOfCoords[i]!.lon)
                minStation = i
            }
        }
        return minStation
    }
    
    // converts m/s to mph
    static func convertSpeed(speed: Double) -> Double{
        let result = (speed / 1609) * 3600
        return round(result * 1000) / 1000
    }
    
    // method that calculates the distance between the users current location and a latitude longitude point
    func calculateDistance(lat: Double, lon: Double) -> Double{
        //Earth's radius in miles
        let R : Double = 3963.1
        let deltaLat = degToRad(deg: lat - coordinates.lat)
        let deltaLon = degToRad(deg: lon - coordinates.lon)
        
        //Haversine Formula
        let a = sin(deltaLat/2) * sin(deltaLat/2) + cos(degToRad(deg: coordinates.lat)) * cos(degToRad(deg: lat)) * sin(deltaLon/2) * sin(deltaLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        let d = c * R
        return d
    }
       
    // method that caculates the distance between two latitude longitude points
    func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double{
        //Earth's radius in miles
        let R : Double = 3963.1
        let deltaLat = degToRad(deg: lat2 - lat1)
        let deltaLon = degToRad(deg: lon2 - lon1)
        
        //Haversine Formula
        let a = sin(deltaLat/2) * sin(deltaLat/2) + cos(degToRad(deg: lat1)) * cos(degToRad(deg: lat2)) * sin(deltaLon/2) * sin(deltaLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        let d = c * R
        return d
    }
    
    
    private func degToRad(deg: Double) -> Double{
        return deg * (Double.pi/180.0)
    }
    
    //public func printCords() -> String{
     //   return coordinates.lat.description + " " + coordinates.lon.description
    //}
}
