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
    
    private override init() {
        super.init()
        
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        //determines how frequent the accelerometer and gyroscope is updating
        motionManager.deviceMotionUpdateInterval = 0.001
    }
    
    //singleton
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
    
    //starts getting user location and motion
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        
        // Start Device Motion Updates (for orientation)
        motionManager.startDeviceMotionUpdates(to: .main) { (motion, error) in
            guard let deviceMotion = motion else { return }
            self.trackOrientation(motion: deviceMotion)
        }
    }
    //stops getting user location and motion
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
    
    //updates the location manager information
    private func updateInfo(){
        gpsSpeed = max(location?.speed ?? 0, 0)
        
        if let location = location {
            Navigation.shared.coordinates = (lat: location.coordinate.latitude, lon: location.coordinate.longitude)
        }
        
        //for notifications
        Navigation.shared.updateStatus()
    }
    
    //uses the gyroscope to adjust the accelerometer's x y and z components
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
    
    //updates the motion values using the adjusted accelertion from the gyroscope
    private func updateMotionValues(acceleration: CMAcceleration){
        //get the difference in time
        let currentTimeStamp = Date().timeIntervalSince1970
        let dt = currentTimeStamp - lastTimeStamp
        lastTimeStamp = currentTimeStamp
        
        
        //multiply by 9.81 because CMMotion's acceleration is in units of G to get it in m/s^2
        //and adds a low pass filter to smooth out shaking and high filter to filter small noise
        self.motionAcceleration = filterAcceleration(newAcceleration: (acceleration.x, acceleration.y, acceleration.z))
    
        //increase the velocity values after the accelertion filters
        motionVelocity.x += motionAcceleration.x * dt
        motionVelocity.y += motionAcceleration.y * dt
        motionVelocity.z += motionAcceleration.z * dt
        
        //removes small noise
        removeVelocityNoise(threshold: 0.01)
        
        //gradually reduces the velocity when acceleration is near zero
        reduceVelocityIfStationary(dt: dt);
        
        //update the speed
        self.motionSpeed = magnitude(value: (x: motionVelocity.x, y: motionVelocity.y, z: motionVelocity.z))
        
        //update the distance traveled using the updated speed
        motionDistanceTraveled += motionSpeed * dt
    }
    
    //reset the distance traveled
    func resetValuesForNextTrip(){
        motionDistanceTraveled = 0
    }
    
    //returns the magnitude of a 3 dimensional vector
    private func magnitude (value: (x: Double, y: Double, z: Double)) -> Double {
        return sqrt(pow(value.x, 2) + pow(value.y, 2) + pow(value.z, 2))
    }
    
    //sets the velocity component to 0 if it is less than the threshold, this removes small noises in velocity
    private func removeVelocityNoise(threshold: Double) {
        motionVelocity.x = abs(motionVelocity.x) > threshold ? motionVelocity.x : 0
        motionVelocity.y = abs(motionVelocity.y) > threshold ? motionVelocity.y : 0
        motionVelocity.z = abs(motionVelocity.z) > threshold ? motionVelocity.z : 0
    }
    
    //smooths out rapid movement such as shakes
    private func applyLowPassFilter(newAcceleration: (x: Double, y: Double, z: Double)) -> (x: Double, y: Double, z: Double) {
        //Smoothing factor for the low pass filter
        let alpha: Double = 0.1;
        
        return (alpha * newAcceleration.x + (1 - alpha) * motionAcceleration.x,
                alpha * newAcceleration.y + (1 - alpha) * motionAcceleration.y,
                alpha * newAcceleration.z + (1 - alpha) * motionAcceleration.z)
    }
    
    //
    private func applyHighPassFilter(newAcceleration: (x: Double, y: Double, z: Double)) -> (x: Double, y: Double, z: Double) {
        var filteredAcceleration: (x: Double, y: Double, z: Double) = (0, 0, 0)
        
        // Smoothing factor for the high-pass filter
        let alpha: Double = 0.1
        
        filteredAcceleration.x = newAcceleration.x - (alpha * (newAcceleration.x + motionAcceleration.x))
        filteredAcceleration.y = newAcceleration.y - (alpha * (newAcceleration.y + motionAcceleration.y))
        filteredAcceleration.z = newAcceleration.z - (alpha * (newAcceleration.z + motionAcceleration.z))
        
        motionAcceleration = newAcceleration
        
        return filteredAcceleration
    }
    
    //combines the low and high pass filters
    private func filterAcceleration(newAcceleration: (x: Double, y: Double, z: Double)) -> (x: Double, y: Double, z: Double) {
        let lowPassFiltered = applyLowPassFilter(newAcceleration: newAcceleration)
        
        let highPassFiltered = applyHighPassFilter(newAcceleration: lowPassFiltered)
        
        return highPassFiltered
    }
    
    //gradually decrease the velocity if the acceleration is near zero
    private func reduceVelocityIfStationary(dt: Double, threshold: Double = 0.05) {
        let magnitude = magnitude(value: motionAcceleration)
        
        // Check if the magnitude of acceleration is near zero
        if (magnitude < threshold) {
            //graduall decrease
            motionVelocity.x *= max(1.0 - (dt * 0.5), 0)
            motionVelocity.y *= max(1.0 - (dt * 0.5), 0)
            motionVelocity.z *= max(1.0 - (dt * 0.5), 0)
        }
    }
}
