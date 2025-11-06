//
//  CameraView.swift
//  places
//
//  Created by Amarpreet Singh on 11/5/25.
//

import SwiftUI
import UIKit
import CoreLocation
import Combine
import Photos
import SwiftData

struct CameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var capturedLocation: CLLocation?
    let modelContext: ModelContext
    @StateObject private var locationManager = LocationManager()

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No update needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, locationManager: locationManager, modelContext: modelContext)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        let locationManager: LocationManager
        let modelContext: ModelContext

        init(_ parent: CameraView, locationManager: LocationManager, modelContext: ModelContext) {
            self.parent = parent
            self.locationManager = locationManager
            self.modelContext = modelContext
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Handle captured image here
            if let image = info[.originalImage] as? UIImage {
                print("Image captured")

                // Store the image and location
                parent.capturedImage = image
                parent.capturedLocation = locationManager.currentLocation

                // Save to SwiftData with reverse geocoding
                if let imageData = image.jpegData(compressionQuality: 0.8),
                   let location = locationManager.currentLocation {

                    // Perform reverse geocoding
                    let geocoder = CLGeocoder()
                    geocoder.reverseGeocodeLocation(location) { placemarks, error in
                        let placemark = placemarks?.first
                        let city = placemark?.locality
                        let state = placemark?.administrativeArea
                        let country = placemark?.country

                        let photo = CapturedPhoto(
                            timestamp: Date(),
                            imageData: imageData,
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            altitude: location.altitude,
                            city: city,
                            state: state,
                            country: country
                        )

                        self.modelContext.insert(photo)
                        do {
                            try self.modelContext.save()
                            print("✅ Photo saved to SwiftData")
                            if let city = city, let country = country {
                                print("📍 Location: \(city), \(state ?? ""), \(country)")
                            }
                        } catch {
                            print("❌ Error saving to SwiftData: \(error)")
                        }
                    }
                }

                // Save to photo library
                savePhotoToLibrary(image: image, location: locationManager.currentLocation)

                // Log location
                if let location = locationManager.currentLocation {
                    print("📍 Location: Latitude: \(location.coordinate.latitude), Longitude: \(location.coordinate.longitude)")
                    print("📍 Altitude: \(location.altitude) meters")
                    print("📍 Accuracy: ±\(location.horizontalAccuracy) meters")
                    print("📍 Timestamp: \(location.timestamp)")
                } else {
                    print("📍 Location not available")
                }
            }
            picker.dismiss(animated: true)
        }

        func savePhotoToLibrary(image: UIImage, location: CLLocation?) {
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else {
                    print("Photo library access denied")
                    return
                }

                PHPhotoLibrary.shared().performChanges({
                    let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                    if let location = location {
                        request.location = location
                    }
                }) { success, error in
                    if success {
                        print("✅ Photo saved to library with location")
                    } else if let error = error {
                        print("❌ Error saving photo: \(error.localizedDescription)")
                    }
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
