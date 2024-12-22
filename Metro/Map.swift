//
//  Map.swift
//  Metro
//
//  Created by Jason Li on 11/22/24.
//

class MetroMap {
    //fields
    var metroMap: [String : Station] = [:]
    var trainsColor: [String : [String]] = [:]
    

    
    init() {
        populateStation()
    }
    
    
    private func populateStation(){
        //adds the green line
        let greenLine: [String] = ["Greenbelt", "College Park-U of Md", "Hyattsville Crossing", "West Hyattsville",
                                   "Fort Totten", "Georgia Ave-Petworth", "Columbia Heights", "U St", "Shaw-Howard U",
                                   "Mt Vernon Sq", "Gallery Place", "Archives", "L'Enfant Plaza", "Waterfront", "Navy Yard-Ballpark",
                                   "Anacostia", "Congress Heights", "Southern Ave", "Naylor Rd", "Suitland", "Branch Ave"]
        addStations(stations: greenLine, color: "Green", trainName: "Greenbelt", otherTrainName:"Branch Ave")
        
        //red line
        let redLine: [String] = [
                   "Shady Grove", "Rockville", "Twinbrook", "North Bethesda", "Grosvenor-Strathmore",
                   "Medical Center", "Bethesda", "Friendship Heights", "Tenleytown-AU", "Van Ness-UDC",
                   "Cleveland Park", "Woodley Park", "Dupont Circle", "Farragut North", "Metro Center",
                   "Gallery Place", "Judiciary Sq", "Union Station", "NoMa-Gallaudet U", "Rhode Island Ave",
                   "Brookland-CUA", "Fort Totten", "Takoma", "Silver Spring", "Forest Glen", "Wheaton",
                   "Glenmont"]
        addStations(stations: redLine, color: "Red", trainName: "Shady Grove", otherTrainName: "Glenmont");
        
        //orangeLine
        let orangeLine: [String] = [
                   "Vienna", "Dunn Loring", "West Falls Church", "East Falls Church", "Ballston-MU",
                   "Virginia Sq-GMU", "Clarendon", "Court House", "Rosslyn", "Foggy Bottom-GWU",
                   "Farragut West", "McPherson Sq", "Metro Center", "Federal Triangle","Smithsonian",
                   "L'Enfant Plaza", "Federal Center SW", "Capitol South", "Eastern Market",
                   "Potomac Ave", "Stadium-Armory", "Minnesota Ave", "Deanwood", "Cheverly",
                   "Landover", "New Carrollton"]
        addStations(stations: orangeLine, color: "Orange", trainName: "Vienna", otherTrainName: "New Carrollton")
        
        //silver line
        let silverLine: [String] = [
                   "Ashburn", "Loudoun Gateway", "Washington Dulles International Airport",
                   "Innovation Center", "Herndon", "Reston Town Center", "Wiehle-Reston East",
                   "Spring Hill", "Greensboro", "Tysons", "McLean", "East Falls Church",
                   "Ballston-MU", "Virginia Sq-GMU", "Clarendon", "Court House", "Rosslyn",
                   "Foggy Bottom-GWU", "Farragut West", "McPherson Sq", "Metro Center",
                   "Federal Triangle", "Smithsonian", "L'Enfant Plaza", "Federal Center SW",
                   "Capitol South", "Eastern Market", "Potomac Ave", "Stadium-Armory",
                   "Benning Rd", "Capitol Heights", "Addison Rd", "Morgan Blvd", "Downtown Largo"]
        addStations(stations: silverLine, color: "Silver", trainName: "Ashburn", otherTrainName: "Downtown Largo")
        
        //yellow line
        let yellowLine: [String] = [
                   "Huntington", "Eisenhower Ave", "King St-Old Town", "Braddock Rd", "Potomac Yard",
                   "Ronald Reagan Washington National Airport", "Crystal City", "Pentagon City", "Pentagon",
                   "L'Enfant Plaza", "Archives", "Gallery Place", "Mt Vernon Sq"]
        addStations(stations: yellowLine, color: "Yellow", trainName: "Huntington", otherTrainName: "Mt Vernon Sq")
        
        //blue line
        let blueLine: [String] = [
                   "Franconia-Springfield", "Van Dorn St", "King St-Old Town",
                    "Braddock Rd", "Potomac Yard", "Ronald Reagan Washington National Airport",
                   "Crystal City", "Pentagon City", "Pentagon", "Arlington Cemetery", "Rosslyn",
                   "Foggy Bottom-GWU", "Farragut West", "McPherson Sq", "Metro Center",
                    "Federal Triangle","Smithsonian", "L'Enfant Plaza", "Federal Center SW",
                   "Capitol South", "Eastern Market", "Potomac Ave", "Stadium-Armory",
                   "Benning Rd", "Capitol Heights", "Addison Rd", "Morgan Blvd", "Downtown Largo"
               ]
        addStations(stations:blueLine, color:"Blue", trainName:"Franconia-Springfield", otherTrainName: "Downtown Largo");
    }
    
    private func addStations(stations: [String], color: String, trainName: String, otherTrainName: String){
        
        trainsColor[trainName, default: []].append(color)
        trainsColor[otherTrainName, default: []].append(color)
        
        
        //loops through the stations list the ..< is iterating
        for i in 0..<stations.count {
            
            //if station at that index is not in the map
            if !metroMap.keys.contains(stations[i]) {
                metroMap[stations[i]] = Station(name: stations[i])
            }
            //adds the edge between the two
            if i > 0 {
                metroMap[stations[i]]?.addNeighbor(neighbor:metroMap[stations[i - 1]]!, color: color, trainName: trainName, otherTrainName: otherTrainName)
            }
        }
    }
    
    public func getShortestPath(start: String, end:String) -> [Station]?{
        
        //checks if the stations exists
        if (metroMap[start] == nil || metroMap[end] == nil){
            print("doesn't exist")
            return nil;
        }
        
        //queue for the BFS traveral initially start with the starting station
        if let initialPath = metroMap[start] {
            var queue: [[Station]] = [[initialPath]]
            
            var paths: [[Station]] = []
            var weights: [Int] = []
            
            while (!queue.isEmpty){
                let currentPath: [Station] = queue.removeFirst()
                let lastStationInCurrentPath: Station = currentPath.last ?? currentPath[0]
                
                // If the last station is the destination, store the path and its weight
                if (lastStationInCurrentPath.name == end){
                    paths.append(currentPath)
                    weights.append(getWeightOfPath(path: currentPath))
                }
                
                
                for neighbor in lastStationInCurrentPath.neighbors.keys{
                    if !currentPath.contains(neighbor){
                        var newPath: [Station] = currentPath
                        newPath.append(neighbor)
                        queue.append(newPath)
                    }
                }
                
            }
            
            //Finding the shortest Path
            
            var minIndex: Int = -1
            var minWeight: Int = Int.max
            
            for i in 0..<paths.count{
                if weights[i] < minWeight{
                    minWeight = weights[i]
                    minIndex = i
                }
            }
            
            if (minIndex == -1){
                return nil
            }
            
            return paths[minIndex]
        }
        return nil
    }
    
    public func getTrainPath(path: [Station]) -> [String]{
        if (path.count <= 1){
            return ["Already at destination"]
        }
        
        var result: [String] = []
        
        var trainsAllowed:[String] = onlyTrains(list: path[0].neighbors[path[1]]!)
        var freqTrain: [String:Int] = [:]
        
        var start: String = path[0].name
        var startColor: [String] = onlyColors(list: (metroMap[start]?.neighbors[path[1]])!)
        
        for i in 0..<path.count-1{
            let currentTrain = onlyTrains(list: path[i].neighbors[path[i+1]]!)
            
            //no matching train means switching trains
            if !contains(list1: trainsAllowed, list2: currentTrain){
                let endColor: [String] = onlyColors(list: (metroMap[path[i-1].name]?.neighbors[path[i]])!)
                
                result.append(contentsOf: createTrainPathString(freq: freqTrain, colors: common(set1: startColor, set2: endColor), start: start, end: path[i].name))
                
                //reset other var
                freqTrain = [:]
                startColor = onlyColors(list: (metroMap[path[i].name]?.neighbors[path[i+1]])!)
                start = path[i].name
                trainsAllowed = currentTrain
            }
            
            freqTrain = updateFreq(freq: freqTrain, list: currentTrain)
            trainsAllowed = common(set1: trainsAllowed, set2: currentTrain)
        }
        
        let endColor: [String] = onlyColors(list: (metroMap[path[path.count-2].name]?.neighbors[path[path.count-1]])!)
        
        result.append(contentsOf: createTrainPathString(freq: freqTrain, colors: common(set1: startColor, set2: endColor), start: start, end: path[path.count-1].name))
        
        return result
        
    }
    
    private func createTrainPathString(freq: [String:Int], colors: [String], start: String, end: String) -> [String]{
        
        let max: Int = getMaxFromMap(freq: freq)
        var stations: [String] = []
        
        //find the more frequent train (can be multiple)
        for s in freq.keys{
            if freq[s]! >= max {
                stations.append(s)
            }
        }
        
        var res: [String] = []
        var result: String = ""
        
        for s in stations{
            let common: [String] = common(set1: colors, set2: trainsColor[s]!)
            result += toString(list:common) + " " + s + " or "
        }
        
        result.removeLast(4)
        result += " Train|\(end)"
        
        res.append(result)
        return res
    }
    
    public func getOrderedSwapTrainPath(list: [String]) -> [Station]{
        var result: [Station] = []
        
        for s in list{
            if let index = s.firstIndex(of: "|"){
                let indexAfter = s.index(after: index)
                result.append(metroMap[String(s[indexAfter...])]!)
            }
        }
        return result
    }
    
    public func getStationsToSwitchMap(list: [String]) -> [Station: String]{
        var result: [Station: String] = [:]
        
        for s in list{
            if let index = s.firstIndex(of: "|"){
                let indexAfter = s.index(after: index)
                result[metroMap[String(s[indexAfter...])]!] = String(s[..<index])
            }
        }
        
        return result
    }
    
    private let colorMap:[String: String] = ["Silver":"🪙", "Orange":"🟠", "Yellow": "🟡",
        "Green":"🟢", "Red": "🔴", "Blue":"🔵"]
    
    private func toString(list: [String]) -> String{
        var result: String = ""
        for i in list{
            result += colorMap[i]!
        }
        return result
    }
    
    private func getMaxFromMap(freq: [String: Int]) -> Int{
        var max: Int = -1
        
        for s in freq.keys{
            if freq[s]! > max{
                max = freq[s]!
            }
        }
        
        return max
    }
    
    private func updateFreq(freq: [String:Int], list: [String]) -> [String:Int]{
        //make freq mutable
        var freq = freq
        
        for s in list{
            if let value = freq[s]{
                freq[s] = value + 1
            }
            else{
                freq[s] = 1
            }
        }
        return freq
    }
    
    private func getWeightOfPath(path: [Station?]) -> Int{
        if path.isEmpty{
            return Int.max
        }
        else if path.count == 1{
            return 1
        }
        
        var weight: Int = 0
        var colorsAllowed: [String]
        
        if let neighborList = path[0]?.neighbors[path[1]!]{
            colorsAllowed = onlyColors(list:neighborList)
            
        
            for i in 1..<path.count-1{
                if let getPathColor = path[i]?.neighbors[path[i+1]!]{
                    let currLineColor = onlyColors(list: getPathColor)
                    
                    //no matching colors meaning line switch
                    if (!contains(list1: colorsAllowed, list2: currLineColor)){
                        colorsAllowed = currLineColor
                        weight += 100
                    }
                    
                    colorsAllowed = common(set1: colorsAllowed, set2: currLineColor)
                    weight += 1
                }
                
            }
        }
        return weight
    }
    
    private func onlyColors(list: [String]) -> [String]{
        var result: [String] = []
        
        for s in list{
            if let index = s.firstIndex(of: "|"){
                result.append(String(s[..<index]))
            }
        }
        
        return result
    }
    
    private func onlyTrains(list: [String]) -> [String]{
        var result: [String] = []
        
        for s in list{
            if let index = s.firstIndex(of: "|"){
                let indexAfter = s.index(after: index)
                result.append(String(s[indexAfter...]))
            }
        }
        
        return result
    }
    
    private func common(set1: [String], set2: [String]) -> [String]{
        var list: [String] = []
        
        for s in set1{
            if (set2.contains(s)){
                list.append(s)
            }
        }
        return list
    }
    
    private func contains(list1: [String], list2: [String]) -> Bool{
        for e in list1{
            if (list2.contains(e)){
                return true
            }
        }
        return false
    }
    
    
    public static func convertToString(list: [Station?]?) -> [String]{
        var result: [String] = []
        
        for s in list ?? []{
            result.append(s!.description)
        }
        return result
    }
}

//class for each station
class Station: Hashable, CustomStringConvertible {
    //field variables
    var name: String = ""
    var neighbors: [Station: [String]] = [:]
    
    //constructor
    init(name: String) {
        self.name = name
    }
    
    // MARK: - Hashable Conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    // MARK: - Equatable Conformance
    static func == (lhs: Station, rhs: Station) -> Bool {
        return lhs.name == rhs.name
    }
    
    //toString method
    var description: String {
        return name
    }
    
    //add neighbors method
    func addNeighbor(neighbor: Station, color: String, trainName: String, otherTrainName: String){
        
        if (!neighbors.keys.contains(neighbor)){
            neighbors[neighbor] = ["\(color)|\(trainName)"]
            neighbor.neighbors[self] = ["\(color)|\(otherTrainName)"]
        }
        else{
            neighbors[neighbor]?.append("\(color)|\(trainName)")
            neighbor.neighbors[self]?.append("\(color)|\(otherTrainName)")
        }

        
        
    }
}
