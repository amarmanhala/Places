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
                                country: country,
                                extractedText: extractedText
                            )

                            self.modelContext.insert(photo)
                            do {
                                try self.modelContext.save()
                                print("✅ Photo saved to SwiftData")
                                if let city = city, let country = country {
                                    print("📍 Location: \(city), \(state ?? ""), \(country)")
                                }
                                if let text = extractedText, !text.isEmpty {
                                    print("📝 Extracted text: \(text)")
                                }
                            } catch {
                                print("❌ Error saving to SwiftData: \(error)")
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
