import Foundation
import CoreLocation
import CoreMotion

class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    
    //Location manager / Gps usage
    private var locationManager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus?
    
    
    var gpsSpeed: Double = 0.0
    
    //Backup for when gps fails, motion variables
    
    //Motion manager
    private var motionManager = CMMotionManager()
    
    @Published var motionAcceleration: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published var motionVelocity: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published var motionDistanceTraveled: Double = 0.0
    
    @Published var motionSpeed: Double = 0
    
    //rotation matrix for orientation
    @Published var rotationMatrix: CMRotationMatrix = CMRotationMatrix()
    
    //timeStamp for motion calculations
    private var lastTimeStamp: TimeInterval = Date().timeIntervalSince1970
    
    private override init(){
        super.init()
        
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        //determines how frequent the accelerometer and gyroscope is updating
        motionManager.deviceMotionUpdateInterval = 0.001
        

    }
    
    static let shared = LocationManager()
    
    func requestAuthorization() {
        // Request "When In Use" authorization first
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            authorizationStatus = manager.authorizationStatus

            if authorizationStatus == .authorizedWhenInUse {
                // If granted "When In Use," request "Always" access
                locationManager.requestAlwaysAuthorization()
            }
        }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        
        // Start Device Motion Updates (for orientation)
        motionManager.startDeviceMotionUpdates(to: .main) { (motion, error) in
            guard let deviceMotion = motion else { return }
            self.trackOrientation(motion: deviceMotion)
        }
    }
    
    func stopUpdatingLocation(){
        locationManager.stopUpdatingLocation()
        
        motionManager.stopDeviceMotionUpdates()
    }
        
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        guard let newLocation = locations.last else { return }
        
        // Determine the source based on location accuracy
        DispatchQueue.main.async {
            self.location = newLocation
        }

        updateInfo()
    }
    
    private func updateInfo(){
        gpsSpeed = max(location?.speed ?? 0, 0)
        
        if let location = location {
            Navigation.shared.coordinates = (lat: location.coordinate.latitude, lon: location.coordinate.longitude)
        }
        
        //for notifications
        Navigation.shared.returnStatus()

    }
    
    
    private func trackOrientation(motion: CMDeviceMotion) {
        // Get rotation matrix to adjust accelerometer readings based on device's orientation
        rotationMatrix = motion.attitude.rotationMatrix
        // Adjust the accelerometer readings (X, Y, Z) based on the rotation matrix
        let adjustedAccelerationX = motion.userAcceleration.x * rotationMatrix.m11 +
                                    motion.userAcceleration.y * rotationMatrix.m12 +
                                    motion.userAcceleration.z * rotationMatrix.m13

        let adjustedAccelerationY = motion.userAcceleration.x * rotationMatrix.m21 +
                                    motion.userAcceleration.y * rotationMatrix.m22 +
                                    motion.userAcceleration.z * rotationMatrix.m23

        let adjustedAccelerationZ = motion.userAcceleration.x * rotationMatrix.m31 +
                                    motion.userAcceleration.y * rotationMatrix.m32 +
                                    motion.userAcceleration.z * rotationMatrix.m33

        // Create an adjusted accelerometer object with all components
        let adjustedAcceleration = CMAcceleration(x: adjustedAccelerationX,
                                                  y: adjustedAccelerationY,
                                                  z: adjustedAccelerationZ)

        // Update the distance using adjusted acceleration data
        updateMotionValues(acceleration: adjustedAcceleration)
    }
    
    
    private func updateMotionValues(acceleration: CMAcceleration){
        let currentTimeStamp = Date().timeIntervalSince1970
        let deltaTime = currentTimeStamp - lastTimeStamp
        
        
        //CCMotion's accleration is in G - 9.81 m/s^2
        let convertedAcceleration = CMAcceleration(x: acceleration.x * 9.81, y: acceleration.y * 9.81, z: acceleration.z * 9.81)
        
        // Reset when deltaTime is too large (or in the beginning)
        let acceleration = detectShake(acceleration: convertedAcceleration)
        resetVelocityIfStationary(acceleration: acceleration)

        motionVelocity.x += acceleration.x * deltaTime
        motionVelocity.y += acceleration.y * deltaTime
        motionVelocity.z += acceleration.z * deltaTime
        
        
        motionDistanceTraveled += magnitude(value: (x: motionVelocity.x, y: motionVelocity.y, z: motionVelocity.z)) * deltaTime
    
        self.motionSpeed = magnitude(value: (x: motionVelocity.x, y: motionVelocity.y, z: motionVelocity.z))
        self.motionAcceleration = (x: acceleration.x, y: acceleration.y, z: acceleration.z)
        lastTimeStamp = currentTimeStamp
    }
    
     func resetValuesForNextTrip(){
        motionDistanceTraveled = 0
    }
    
    private func resetVelocityIfStationary(acceleration: CMAcceleration) {
        let threshold = 0.05 // Threshold for minimal acceleration
        
        // Check if the magnitude of acceleration is near zero
        let magnitude = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
        
        if magnitude < threshold {
            motionVelocity = (0, 0, 0)
        }
    }
    
    private func magnitude (value: (x: Double, y: Double, z: Double)) -> Double {
        return sqrt(pow(value.x, 2) + pow(value.y, 2) + pow(value.z, 2))
    }
    
    private func ignoreSmallMovements(acceleration: CMAcceleration, threshold: Double = 0.05) -> CMAcceleration {
        return CMAcceleration(
            x: abs(acceleration.x) > threshold ? acceleration.x : 0,
            y: abs(acceleration.y) > threshold ? acceleration.y : 0,
            z: abs(acceleration.z) > threshold ? acceleration.z : 0
        )
    }
    
    //if the acceleration is drasitcally different from the previous acceleration we can determine that hard shaking has been involed
    private func detectShake(acceleration: CMAcceleration, threshold: Double = 0.5 * 9.81) -> CMAcceleration {
        let magnitudeInitialAcceleration = magnitude(value: (x: self.motionAcceleration.x, y: self.motionAcceleration.y, z: self.motionAcceleration.z))
        let magnitudeFinalAcceleration = magnitude(value: (x: acceleration.x, y: acceleration.y, z: acceleration.z))
        
        let delta = abs(magnitudeFinalAcceleration - magnitudeInitialAcceleration)
        
        //within threshold
        if delta < threshold {
            return acceleration
        }
        //shake detected
        else{
            print("Shake detected")
            return CMAcceleration(x: 0, y: 0, z: 0)
        }
        
    }
}
