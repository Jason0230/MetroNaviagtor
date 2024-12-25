import SwiftUI
import Combine

struct ContentView: View {
    
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var locationManager = LocationManager.shared

    @State var map = MetroMap()
    @State var path: [Station] = []
    @State var swapTrains: [String] = []
    
    @State var orderedTrainSwapPath: [Station] = []
    @State var trainSwapPathMap:[Station: String] = [:]
    
    @State var start: String
    @State var end: String
    
    @ObservedObject private var nav = Navigation.shared
    
    var body: some View {
        //Separate VStack for the Alert
        VStack{
            Alert()
        }.transition(.move(edge: .top))
            .frame(maxWidth: UIScreen.main.bounds.width * 0.9, maxHeight: 100, alignment: .top).padding()
        
        //Rest of the infomation
        VStack(spacing: 10) {
            
            //Title text for the start and end stations
            Text("\(start) to \(end)").frame(minWidth: 150, minHeight: 50).font(Font.custom("Avenir", size: 25)).bold()
            
            //display the next station
            Text(nav.nextDestinationStatus).bold().font(Font.custom("Avenir", size: 15))
            
            //distance from next station for both GPS and Motion
            Text(nav.distanceFromNextDestination).bold().font(Font.custom("Avenir", size: 15))
            
            //displays the traveling speed
            Text(nav.travelingSpeed).bold().font(Font.custom("Avenir", size: 15))
            
            //displays the distance that the motion manager got
            Text(String(nav.getMotionDistanceTraveled()) + " miles traveled").bold().font(Font.custom("Avenir", size: 15))
            
            //displays the next 5 stations in the path
            Text("Path: " + nav.nextStations).bold().font(Font.custom("Avenir", size: 15))
            
            //displays the next for when to switch stations
            Text(nav.switchingStationText).bold().font(Font.custom("Avenir", size: 15))
            
            //displays the total number of stops are away from the destination
            Text(nav.stopsAwayFromDestination).bold().font(Font.custom("Avenir", size: 15))
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.95)
        .onAppear(){
            // Request location permissions
            locationManager.requestAuthorization()
            locationManager.startUpdatingLocation()
            initializeMapData()
        }.onChange(of:scenePhase) {
            if scenePhase == .active {
                // App is active, start location updates
                locationManager.startUpdatingLocation()
            } else if scenePhase == .background {
                // Ensure updates continue in the background
                locationManager.startUpdatingLocation()
                
            }
        }.onDisappear{
            //stop getting info on the beginning screen
            locationManager.stopUpdatingLocation()
        }
    }
    
    func initializeMapData() {
        if let shortestPath = map.getShortestPath(start: start, end: end) {
            path = shortestPath
            swapTrains = map.getTrainPath(path: path)
            orderedTrainSwapPath = map.getOrderedSwapTrainPath(path: swapTrains)
            trainSwapPathMap = map.getStationsToSwitchMap(path: swapTrains)
            
            // Update Navigation's properties
            Navigation.shared.path = path
            Navigation.shared.stationsToSwitch = trainSwapPathMap
            Navigation.shared.orderOfStationSwitch = orderedTrainSwapPath
        }
    
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(start:"Herndon", end:"Greenbelt")
    }
}

