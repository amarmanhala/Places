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
import Vision
import MapKit

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

                // Save to SwiftData with reverse geocoding and text extraction
                if let imageData = image.jpegData(compressionQuality: 0.8),
                   let location = locationManager.currentLocation {

                    // Extract text from image using Vision
                    self.extractText(from: image) { extractedText in
                        // If we extracted store name, search for nearby matching store
                        if let storeName = extractedText, !storeName.isEmpty {
                            print("🔍 Searching for nearby '\(storeName)'...")

                            self.searchNearbyStore(storeName: storeName, nearLocation: location) { storeLocation, verifiedName, city, state, country, address, phoneNumber, poiCategory in
                                // Use store location if found, otherwise use current location
                                let finalLocation = storeLocation ?? location
                                let finalName = verifiedName ?? extractedText

                                // If store was found, we already have address components
                                // Otherwise, reverse geocode current location
                                if storeLocation != nil {
                                    // Store found! Use its data and categorize
                                    let category = CategoryHelper.categorize(poiCategory: poiCategory, extractedText: finalName)

                                    let photo = CapturedPhoto(
                                        timestamp: Date(),
                                        imageData: imageData,
                                        latitude: finalLocation.coordinate.latitude,
                                        longitude: finalLocation.coordinate.longitude,
                                        altitude: finalLocation.altitude,
                                        city: city,
                                        state: state,
                                        country: country,
                                        address: address,
                                        phoneNumber: phoneNumber,
                                        extractedText: finalName,
                                        category: category
                                    )

                                    self.savePhoto(photo, city: city, state: state, country: country, text: finalName)
                                } else {
                                    // No store found, reverse geocode current location
                                    let geocoder = CLGeocoder()
                                    geocoder.reverseGeocodeLocation(finalLocation) { placemarks, error in
                                        let placemark = placemarks?.first
                                        let city = placemark?.locality
                                        let state = placemark?.administrativeArea
                                        let country = placemark?.country

                                        // Build address from reverse geocode
                                        var addressComponents: [String] = []
                                        if let subThoroughfare = placemark?.subThoroughfare {
                                            addressComponents.append(subThoroughfare)
                                        }
                                        if let thoroughfare = placemark?.thoroughfare {
                                            addressComponents.append(thoroughfare)
                                        }
                                        let fullAddress = addressComponents.isEmpty ? nil : addressComponents.joined(separator: " ")

                                        // Categorize using keyword fallback
                                        let category = CategoryHelper.categorize(poiCategory: nil, extractedText: extractedText)

                                        let photo = CapturedPhoto(
                                            timestamp: Date(),
                                            imageData: imageData,
                                            latitude: finalLocation.coordinate.latitude,
                                            longitude: finalLocation.coordinate.longitude,
                                            altitude: finalLocation.altitude,
                                            city: city,
                                            state: state,
                                            country: country,
                                            address: fullAddress,
                                            phoneNumber: nil,
                                            extractedText: extractedText,
                                            category: category
                                        )

                                        self.savePhoto(photo, city: city, state: state, country: country, text: extractedText)
                                    }
                                }
                            }
                        } else {
                            // No text extracted, just reverse geocode current location
                            let geocoder = CLGeocoder()
                            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                                let placemark = placemarks?.first
                                let city = placemark?.locality
                                let state = placemark?.administrativeArea
                                let country = placemark?.country

                                // Build address from reverse geocode
                                var addressComponents: [String] = []
                                if let subThoroughfare = placemark?.subThoroughfare {
                                    addressComponents.append(subThoroughfare)
                                }
                                if let thoroughfare = placemark?.thoroughfare {
                                    addressComponents.append(thoroughfare)
                                }
                                let fullAddress = addressComponents.isEmpty ? nil : addressComponents.joined(separator: " ")

                                // No text to categorize, default to "Other"
                                let category = "Other"

                                let photo = CapturedPhoto(
                                    timestamp: Date(),
                                    imageData: imageData,
                                    latitude: location.coordinate.latitude,
                                    longitude: location.coordinate.longitude,
                                    altitude: location.altitude,
                                    city: city,
                                    state: state,
                                    country: country,
                                    address: fullAddress,
                                    phoneNumber: nil,
                                    extractedText: nil,
                                    category: category
                                )

                                self.savePhoto(photo, city: city, state: state, country: country, text: nil)
                            }
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

        func extractText(from image: UIImage, completion: @escaping (String?) -> Void) {
            guard let cgImage = image.cgImage else {
                completion(nil)
                return
            }

            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    print("❌ Text recognition error: \(error!.localizedDescription)")
                    completion(nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    completion(nil)
                    return
                }

                // Filter and sort by confidence and size
                let recognizedTexts = observations.compactMap { observation -> (text: String, confidence: Float, size: CGFloat)? in
                    guard let candidate = observation.topCandidates(1).first,
                          candidate.confidence > 0.5 else { // Only high confidence text
                        return nil
                    }

                    // Calculate approximate text size from bounding box
                    let boundingBox = observation.boundingBox
                    let size = boundingBox.width * boundingBox.height

                    return (candidate.string, candidate.confidence, size)
                }

                // Sort by size (larger text first) then by confidence
                let sortedTexts = recognizedTexts
                    .sorted { $0.size > $1.size }
                    .map { $0.text }

                // Debug: print all recognized text
                print("📝 All recognized text: \(sortedTexts)")

                // Take only the most prominent text (likely the store sign)
                let extractedText = sortedTexts.first
                completion(extractedText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("❌ Failed to perform text recognition: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }

        func savePhoto(_ photo: CapturedPhoto, city: String?, state: String?, country: String?, text: String?) {
            self.modelContext.insert(photo)
            do {
                try self.modelContext.save()
                print("✅ Photo saved to SwiftData")
                if let city = city, let country = country {
                    print("📍 Location: \(city), \(state ?? ""), \(country)")
                }
                if let text = text, !text.isEmpty {
                    print("📝 Extracted text: \(text)")
                }
            } catch {
                print("❌ Error saving to SwiftData: \(error)")
            }
        }

        func searchNearbyStore(storeName: String, nearLocation: CLLocation, completion: @escaping (CLLocation?, String?, String?, String?, String?, String?, String?, MKPointOfInterestCategory?) -> Void) {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = storeName

            // Search within 500m radius of current location
            let region = MKCoordinateRegion(
                center: nearLocation.coordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
            request.region = region

            let search = MKLocalSearch(request: request)
            search.start { response, error in
                guard let response = response, !response.mapItems.isEmpty else {
                    print("⚠️ No nearby stores found for '\(storeName)', using current location")
                    completion(nil, nil, nil, nil, nil, nil, nil, nil)
                    return
                }

                // Find closest store to current location
                let sortedByDistance = response.mapItems.sorted { item1, item2 in
                    let loc1 = CLLocation(latitude: item1.placemark.coordinate.latitude,
                                         longitude: item1.placemark.coordinate.longitude)
                    let loc2 = CLLocation(latitude: item2.placemark.coordinate.latitude,
                                         longitude: item2.placemark.coordinate.longitude)
                    return nearLocation.distance(from: loc1) < nearLocation.distance(from: loc2)
                }

                if let nearestStore = sortedByDistance.first {
                    let storeLocation = CLLocation(
                        latitude: nearestStore.placemark.coordinate.latitude,
                        longitude: nearestStore.placemark.coordinate.longitude
                    )

                    let distance = nearLocation.distance(from: storeLocation)
                    print("🎯 Found '\(nearestStore.name ?? storeName)' at \(Int(distance))m away")

                    // Extract address components
                    let city = nearestStore.placemark.locality
                    let state = nearestStore.placemark.administrativeArea
                    let country = nearestStore.placemark.country
                    let verifiedName = nearestStore.name

                    // Build full street address
                    var addressComponents: [String] = []
                    if let subThoroughfare = nearestStore.placemark.subThoroughfare {
                        addressComponents.append(subThoroughfare)
                    }
                    if let thoroughfare = nearestStore.placemark.thoroughfare {
                        addressComponents.append(thoroughfare)
                    }
                    let fullAddress = addressComponents.isEmpty ? nil : addressComponents.joined(separator: " ")

                    // Get phone number and POI category
                    let phoneNumber = nearestStore.phoneNumber
                    let poiCategory = nearestStore.pointOfInterestCategory

                    if let phone = phoneNumber {
                        print("📞 Phone: \(phone)")
                    }
                    if let poi = poiCategory {
                        print("🏷️ Category: \(poi.rawValue)")
                    }

                    completion(storeLocation, verifiedName, city, state, country, fullAddress, phoneNumber, poiCategory)
                } else {
                    completion(nil, nil, nil, nil, nil, nil, nil, nil)
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
