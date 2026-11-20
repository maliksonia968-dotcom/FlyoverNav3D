import SwiftUI
import MapKit
import CoreLocation

@main
struct FlyoverNavApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var heading: CLHeading?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }
}

struct ContentView: View {
    @StateObject private var locManager = LocationManager()
    @State private var destinationText = ""
    @State private var route: MKRoute?
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        followsHeading: true,
        fallback: .automatic
    )
    @State private var isNavigating = false

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                UserAnnotation()
                if let route = route {
                    MapPolyline(route.polyline)
                        .stroke(.cyan, lineWidth: 8)
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .onChange(of: locManager.location) { _, newLoc in
                if isNavigating, let loc = newLoc {
                    withAnimation(.linear(duration: 0.5)) {
                        cameraPosition = .camera(
                            MapCamera(
                                centerCoordinate: loc.coordinate,
                                distance: 90,
                                heading: locManager.heading?.trueHeading ?? loc.course,
                                pitch: 78
                            )
                        )
                    }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 8) {
                HStack {
                    TextField("Search destination in India...", text: $destinationText)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .submitLabel(.search)
                        .onSubmit { calculateRoute() }

                    Button(isNavigating ? "Stop" : "Go") {
                        if isNavigating {
                            isNavigating = false
                            route = nil
                        } else {
                            calculateRoute()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isNavigating ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                if let route = route {
                    Text("Distance: \(String(format: "%.1f", route.distance / 1000)) km • ETA: \(Int(route.expectedTravelTime / 60)) min")
                        .font(.caption.bold())
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }

    func calculateRoute() {
        guard let userCoord = locManager.location?.coordinate, !destinationText.isEmpty else { return }
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = destinationText
        searchRequest.region = MKCoordinateRegion(center: userCoord, latitudinalMeters: 50000, longitudinalMeters: 50000)

        MKLocalSearch(request: searchRequest).start { response, _ in
            guard let destItem = response?.mapItems.first else { return }
            let dirRequest = MKDirections.Request()
            dirRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: userCoord))
            dirRequest.destination = destItem
            dirRequest.transportType = .automobile

            MKDirections(request: dirRequest).calculate { dirResponse, _ in
                if let firstRoute = dirResponse?.routes.first {
                    self.route = firstRoute
                    self.isNavigating = true
                }
            }
        }
    }
}
