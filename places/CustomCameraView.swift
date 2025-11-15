//
//  CustomCameraView.swift
//  places
//
//  Created by Claude Code
//

import SwiftUI
import AVFoundation
import CoreLocation
import SwiftData
import Vision
import MapKit
import Photos
import Combine

// OCR Candidate for user selection (future feature)
struct OCRCandidate: Identifiable {
    let id = UUID()
    let text: String
    let score: Float
    let confidence: Float
}

struct CustomCameraView: View {
    @Environment(\.dismiss) var dismiss
    let modelContext: ModelContext
    @Binding var showPlacesView: Bool

    @StateObject private var camera = CameraManager()
    @StateObject private var locationManager = LocationManager()
    @State private var capturedImage: UIImage?
    @State private var showPhotoPreview = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Top Controls (on camera)
                    HStack {
                        Spacer()

                        // Flash Button (top right)
                        Button(action: {
                            camera.toggleFlash()
                        }) {
                            Image(systemName: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 30)
                    .zIndex(1)

                    // Camera Preview
                    CameraPreview(camera: camera)
                        .frame(height: UIScreen.main.bounds.height * 0.65)
                        .clipped()
                }

                Spacer()

                // Bottom Controls (centered in remaining space)
                HStack(alignment: .center) {
                    // Places Button (left)
                    Button {
                        // Very light haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                        impactFeedback.impactOccurred()

                        showPlacesView = true
                    } label: {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color(red: 40/255, green: 40/255, blue: 40/255))
                            .clipShape(Circle())
                    }

                    
                    .padding(.leading, 35)

                    Spacer()

                    // Capture Button (center)
                    Button(action: {
                        camera.capturePhoto()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)

                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 70, height: 70)
                        }
                    }

                    Spacer()

                    // Rotate Camera Button (right)
                    Button(action: {
                        camera.flipCamera()
                    }) {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color(red: 40/255, green: 40/255, blue: 40/255))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 35)
                }

                Spacer()
            }
        }
        .onAppear {
            camera.setupCamera()
            camera.onPhotoCaptured = { image in
                capturedImage = image
                showPhotoPreview = true
            }
        }
        .onDisappear {
            camera.stopSession()
        }
        .fullScreenCover(isPresented: $showPhotoPreview) {
            if let image = capturedImage {
                PhotoPreviewView(
                    image: image,
                    locationManager: locationManager,
                    modelContext: modelContext,
                    onDone: {
                        showPhotoPreview = false
                        capturedImage = nil
                    },
                    onRetake: {
                        showPhotoPreview = false
                        capturedImage = nil
                    }
                )
            }
        }
    }
}

// Photo Preview View
struct PhotoPreviewView: View {
    let image: UIImage
    let locationManager: LocationManager
    let modelContext: ModelContext
    let onDone: () -> Void
    let onRetake: () -> Void

    @State private var isProcessing = false
    @State private var showInfoSheet = true
    @State private var isLoadingData = true
    @State private var extractedText: String?
    @State private var city: String?
    @State private var state: String?
    @State private var country: String?
    @State private var address: String?
    @State private var phoneNumber: String?
    @State private var category: String?
    @State private var selectedDetent: PresentationDetent = .height(300)

    var locationText: String {
        if let city = city, let country = country {
            if let state = state {
                return "\(city), \(state), \(country)"
            } else {
                return "\(city), \(country)"
            }
        } else if let location = locationManager.currentLocation {
            return String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
        } else {
            return "Location not available"
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Image preview
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            // Processing indicator
            if isProcessing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            PhotoPreviewInfoSheet(
                image: image,
                locationManager: locationManager,
                isLoadingData: isLoadingData,
                extractedText: extractedText,
                city: city,
                state: state,
                country: country,
                address: address,
                phoneNumber: phoneNumber,
                category: category,
                locationText: locationText,
                onRetake: onRetake,
                onDone: {
                    isProcessing = true
                    handleCapturedPhoto(image)
                }
            )
            .presentationDetents([.height(90), .height(300), .large], selection: $selectedDetent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
            .interactiveDismissDisabled()
        }
        .onAppear {
            // Start extracting text and location info
            loadPhotoInfo()
        }
    }

    func loadPhotoInfo() {
        // Extract text
        extractText(from: image) { text in
            DispatchQueue.main.async {
                self.extractedText = text
            }

            // Search for nearby store if text was found
            if let storeName = text, !storeName.isEmpty, let location = locationManager.currentLocation {
                searchNearbyStore(storeName: storeName, nearLocation: location) { storeLocation, verifiedName, foundCity, foundState, foundCountry, foundAddress, foundPhone, poiCategory in
                    DispatchQueue.main.async {
                        if storeLocation != nil {
                            self.extractedText = verifiedName ?? text
                            self.city = foundCity
                            self.state = foundState
                            self.country = foundCountry
                            self.address = foundAddress
                            self.phoneNumber = foundPhone
                            self.category = CategoryHelper.categorize(poiCategory: poiCategory, extractedText: verifiedName ?? text)
                            self.isLoadingData = false

                            // Trigger haptic feedback
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        } else {
                            reverseGeocodeLocation()
                        }
                    }
                }
            } else {
                reverseGeocodeLocation()
            }
        }
    }

    func reverseGeocodeLocation() {
        guard let location = locationManager.currentLocation else {
            isLoadingData = false
            return
        }

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                let placemark = placemarks?.first
                self.city = placemark?.locality
                self.state = placemark?.administrativeArea
                self.country = placemark?.country

                var addressComponents: [String] = []
                if let subThoroughfare = placemark?.subThoroughfare {
                    addressComponents.append(subThoroughfare)
                }
                if let thoroughfare = placemark?.thoroughfare {
                    addressComponents.append(thoroughfare)
                }
                self.address = addressComponents.isEmpty ? nil : addressComponents.joined(separator: " ")
                self.category = CategoryHelper.categorize(poiCategory: nil, extractedText: self.extractedText)
                self.isLoadingData = false

                // Trigger haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }

    func handleCapturedPhoto(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8),
              let location = locationManager.currentLocation else {
            print("❌ Missing image data or location")
            return
        }

        // Extract text from image
        extractText(from: image) { extractedText in
            // If we extracted store name, search for nearby matching store
            if let storeName = extractedText, !storeName.isEmpty {
                print("🔍 Searching for nearby '\(storeName)'...")

                searchNearbyStore(storeName: storeName, nearLocation: location) { storeLocation, verifiedName, city, state, country, address, phoneNumber, poiCategory in
                    let finalLocation = storeLocation ?? location
                    let finalName = verifiedName ?? extractedText

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

                        savePhoto(photo, city: city, state: state, country: country, text: finalName)
                    } else {
                        // No store found, reverse geocode current location
                        reverseGeocodeAndSave(imageData: imageData, location: finalLocation, extractedText: extractedText)
                    }
                }
            } else {
                // No text extracted, reverse geocode current location
                reverseGeocodeAndSave(imageData: imageData, location: location, extractedText: nil)
            }
        }

        // Save to photo library
        savePhotoToLibrary(image: image, location: location)
    }

    func reverseGeocodeAndSave(imageData: Data, location: CLLocation, extractedText: String?) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            let placemark = placemarks?.first
            let city = placemark?.locality
            let state = placemark?.administrativeArea
            let country = placemark?.country

            var addressComponents: [String] = []
            if let subThoroughfare = placemark?.subThoroughfare {
                addressComponents.append(subThoroughfare)
            }
            if let thoroughfare = placemark?.thoroughfare {
                addressComponents.append(thoroughfare)
            }
            let fullAddress = addressComponents.isEmpty ? nil : addressComponents.joined(separator: " ")

            // Categorize using keyword fallback (no POI category available)
            let category = CategoryHelper.categorize(poiCategory: nil, extractedText: extractedText)

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
                extractedText: extractedText,
                category: category
            )

            savePhoto(photo, city: city, state: state, country: country, text: extractedText)
        }
    }

    func savePhoto(_ photo: CapturedPhoto, city: String?, state: String?, country: String?, text: String?) {
        modelContext.insert(photo)
        do {
            try modelContext.save()
            print("✅ Photo saved to SwiftData")
            if let city = city, let country = country {
                print("📍 Location: \(city), \(state ?? ""), \(country)")
            }
            if let text = text, !text.isEmpty {
                print("📝 Extracted text: \(text)")
            }

            // Call onDone after successful save
            DispatchQueue.main.async {
                onDone()
            }
        } catch {
            print("❌ Error saving to SwiftData: \(error)")
            DispatchQueue.main.async {
                onDone()
            }
        }
    }

    func searchNearbyStore(storeName: String, nearLocation: CLLocation, completion: @escaping (CLLocation?, String?, String?, String?, String?, String?, String?, MKPointOfInterestCategory?) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = storeName

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

                let city = nearestStore.placemark.locality
                let state = nearestStore.placemark.administrativeArea
                let country = nearestStore.placemark.country
                let verifiedName = nearestStore.name

                var addressComponents: [String] = []
                if let subThoroughfare = nearestStore.placemark.subThoroughfare {
                    addressComponents.append(subThoroughfare)
                }
                if let thoroughfare = nearestStore.placemark.thoroughfare {
                    addressComponents.append(thoroughfare)
                }
                let fullAddress = addressComponents.isEmpty ? nil : addressComponents.joined(separator: " ")
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

    func extractText(from image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let startTime = Date()

        DispatchQueue.global(qos: .userInitiated).async {
            // MARK: - Multi-Pass OCR Strategy
            // Try multiple approaches and combine results for best accuracy

            var allResults: [(text: String, confidence: Float, size: CGFloat, boundingBox: CGRect, method: String)] = []

            // Pass 1: Standard OCR (baseline - ensures backward compatibility)
            if let standardResults = self.performStandardOCR(on: cgImage) {
                allResults.append(contentsOf: standardResults.map { ($0.text, $0.confidence, $0.size, $0.boundingBox, "standard") })
            }

            // Pass 2A: Enhanced OCR with aggressive preprocessing (for neon/high-contrast)
            if let enhancedImage = self.preprocessImageForOCR(image, mode: .aggressive) {
                if let enhancedResults = self.performEnhancedOCR(on: enhancedImage) {
                    allResults.append(contentsOf: enhancedResults.map { ($0.text, $0.confidence, $0.size, $0.boundingBox, "enhanced-aggressive") })
                }
            }

            // Pass 2B: Enhanced OCR with gentle preprocessing (for cursive/script)
            if let gentleImage = self.preprocessImageForOCR(image, mode: .gentle) {
                if let gentleResults = self.performEnhancedOCR(on: gentleImage) {
                    allResults.append(contentsOf: gentleResults.map { ($0.text, $0.confidence, $0.size, $0.boundingBox, "enhanced-gentle") })
                }
            }

            // Pass 2C: Color-boosted preprocessing (for red/colored text)
            if let colorImage = self.preprocessImageForOCR(image, mode: .colorBoost) {
                if let colorResults = self.performEnhancedOCR(on: colorImage) {
                    allResults.append(contentsOf: colorResults.map { ($0.text, $0.confidence, $0.size, $0.boundingBox, "enhanced-color") })
                }
            }

            // Pass 3: Fast recognition for quick text (fallback)
            if let fastResults = self.performFastOCR(on: cgImage) {
                allResults.append(contentsOf: fastResults.map { ($0.text, $0.confidence, $0.size, $0.boundingBox, "fast") })
            }

            // Analyze image for brightness/neon detection
            let brightnessMap = self.analyzeBrightness(in: image)

            // Combine and rank results with brightness analysis
            let (bestResult, topCandidates) = self.selectBestResultWithAlternatives(from: allResults, brightnessMap: brightnessMap, imageSize: image.size)

            // Calculate processing time
            let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)

            // Capture console log output
            let consoleLog = self.captureConsoleLog(allResults: allResults, bestResult: bestResult)

            // Log to database for analysis
            self.logToDatabase(
                image: image,
                allResults: allResults,
                topCandidates: topCandidates,
                brightnessMap: brightnessMap,
                processingTime: processingTime,
                consoleLog: consoleLog
            )

            // Detailed logging for daily testing
            self.logOCRResults(allResults, bestResult: bestResult)

            DispatchQueue.main.async {
                completion(bestResult)
            }
        }
    }

    // MARK: - Database Logging
    private func logToDatabase(
        image: UIImage,
        allResults: [(text: String, confidence: Float, size: CGFloat, boundingBox: CGRect, method: String)],
        topCandidates: [OCRCandidate],
        brightnessMap: [[Float]],
        processingTime: Int,
        consoleLog: String
    ) {
        // Calculate metadata
        let imageHash = OCRLogger.shared.hashImage(image)
        let imagePath = OCRLogger.shared.saveImage(image, hash: imageHash)
        let brightnessAvg = brightnessMap.flatMap { $0 }.reduce(0, +) / Float(brightnessMap.flatMap { $0 }.count)
        let timeOfDay = OCRLogger.shared.getTimeOfDay()

        // Get selected result details
        let bestCandidate = topCandidates.first
        let selectedText = bestCandidate?.text
        let selectedScore = bestCandidate?.score
        let selectedConfidence = bestCandidate?.confidence

        // Find which method produced the best result
        var selectedMethod: String? = nil
        var selectedPosition: (x: Float, y: Float)? = nil
        var selectedSize: Float? = nil

        if let selectedText = selectedText {
            // Find the result that matches selected text
            if let match = allResults.first(where: { $0.text.lowercased() == selectedText.lowercased() }) {
                selectedMethod = match.method
                selectedPosition = (Float(match.boundingBox.midX), Float(match.boundingBox.midY))
                selectedSize = Float(match.size)
            }
        }

        // Create JSON for all candidates
        let candidatesJSON = topCandidates.map { candidate in
            [
                "text": candidate.text,
                "score": candidate.score,
                "confidence": candidate.confidence
            ]
        }
        let candidatesJSONString = (try? JSONSerialization.data(withJSONObject: candidatesJSON))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        // Create JSON for methods summary
        let methodsUsed = Set(allResults.map { $0.method })
        let methodsSummary = methodsUsed.map { method in
            let count = allResults.filter { $0.method == method }.count
            return [
                "method": method,
                "detections": count
            ]
        }
        let methodsJSONString = (try? JSONSerialization.data(withJSONObject: methodsSummary))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        // Detect characteristics
        let hasBrightText = brightnessAvg > 0.6
        let textPosition = (selectedPosition?.y ?? 0) > 0.5 ? "upper" : "lower"

        // Track Vision classification usage
        let usedVision = allResults.contains { $0.method == "vision-classification" }
        let visionMatch = selectedMethod == "vision-classification"

        // Create OCR attempt record
        let attempt = OCRLogger.OCRAttempt(
            imageHash: imageHash,
            imagePath: imagePath,
            brightnessAvg: brightnessAvg,
            timeOfDay: timeOfDay,
            selectedText: selectedText,
            selectedScore: selectedScore,
            selectedConfidence: selectedConfidence,
            selectedMethod: selectedMethod,
            selectedPositionX: selectedPosition?.x,
            selectedPositionY: selectedPosition?.y,
            selectedSize: selectedSize,
            allCandidates: candidatesJSONString,
            allMethodsSummary: methodsJSONString,
            hasBrightText: hasBrightText,
            dominantColor: nil, // TODO: Add color detection
            textPosition: textPosition,
            processingTimeMs: processingTime,
            numCandidates: topCandidates.count,
            numMethodsDetected: methodsUsed.count,
            usedVisionClassification: usedVision,
            visionClassificationMatch: visionMatch,
            consoleLog: consoleLog
        )

        OCRLogger.shared.logOCRAttempt(attempt)
    }

    private func captureConsoleLog(allResults: [(text: String, confidence: Float, size: CGFloat, boundingBox: CGRect, method: String)], bestResult: String?) -> String {
        var log = ""

        // Group by method
        let byMethod = Dictionary(grouping: allResults) { $0.method }

        for (method, items) in byMethod.sorted(by: { $0.key < $1.key }) {
            log += "\(method): "
            let texts = items.sorted(by: { $0.confidence > $1.confidence }).prefix(3).map { $0.text }
            log += texts.joined(separator: ", ")
            log += "\n"
        }

        log += "Selected: \(bestResult ?? "nil")"

        return log
    }

    // MARK: - Standard OCR (Baseline)
    private func performStandardOCR(on cgImage: CGImage) -> [(text: String, confidence: Float, size: CGFloat, boundingBox: CGRect)]? {
        var results: [(text: String, confidence: Float, size: CGFloat, boundingBox: CGRect)] = []
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }

            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            results = observations.compactMap { observation -> (text: String, confidence: Float, size: CGFloat, boundingBox: CGRect)? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence > 0.5 else {
                    return nil
                }

                let boundingBox = observation.boundingBox
                let size = boundingBox.width * boundingBox.height

                return (candidate.string, candidate.confidence, size, boundingBox)
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            semaphore.wait()
            return results.isEmpty ? nil : results
        } catch {
            return nil
        }
    }

    // MARK: - Enhanced OCR (for nighttime, neon, reflections)
    private func performEnhancedOCR(on image: UIImage) -> [(text: String, confidence: Float, size: CGFloat, boundingBox: CGRect)]? {
        guard let cgImage = image.cgImage else { return nil }

        var results: [(text: String, confidence: Float, size: CGFloat, boundingBox: CGRect)] = []
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }

            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            results = observations.compactMap { observation -> (text: String, confidence: Float, size: CGFloat, boundingBox: CGRect)? in
                // Even lower confidence threshold for enhanced preprocessing (cursive text often scores lower)
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence > 0.2 else {
                    return nil
                }

                let boundingBox = observation.boundingBox
                let size = boundingBox.width * boundingBox.height

                return (candidate.string, candidate.confidence, size, boundingBox)
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.03 // Detect smaller text (useful for storefronts)

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            semaphore.wait()
            return results.isEmpty ? nil : results
        } catch {
            return nil
        }
    }

    // MARK: - Fast OCR (Fallback)
    private func performFastOCR(on cgImage: CGImage) -> [(text: String, confidence: Float, size: CGFloat, boundingBox: CGRect)]? {
        var results: [(text: String, confidence: Float, size: CGFloat, boundingBox: CGRect)] = []
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }

            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            results = observations.compactMap { observation -> (text: String, confidence: Float, size: CGFloat, boundingBox: CGRect)? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence > 0.6 else {
                    return nil
                }

                let boundingBox = observation.boundingBox
                let size = boundingBox.width * boundingBox.height

                return (candidate.string, candidate.confidence, size, boundingBox)
            }
        }

        request.recognitionLevel = .fast
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            semaphore.wait()
            return results.isEmpty ? nil : results
        } catch {
            return nil
        }
    }

    // MARK: - Image Preprocessing
    enum PreprocessingMode {
        case aggressive  // For neon/high-contrast (strong filters)
        case gentle      // For cursive/script fonts (minimal processing)
        case colorBoost  // For red/colored text (saturation boost)
    }

    private func preprocessImageForOCR(_ image: UIImage, mode: PreprocessingMode) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let context = CIContext(options: nil)
        var processedImage = ciImage

        switch mode {
        case .aggressive:
            // Strong preprocessing for neon/nighttime/low-contrast
            // 1. High contrast boost
            if let contrastFilter = CIFilter(name: "CIColorControls") {
                contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
                contrastFilter.setValue(1.5, forKey: kCIInputContrastKey) // Strong contrast
                contrastFilter.setValue(1.2, forKey: kCIInputBrightnessKey) // Brightness boost
                contrastFilter.setValue(1.0, forKey: kCIInputSaturationKey)
                if let output = contrastFilter.outputImage {
                    processedImage = output
                }
            }

            // 2. Strong sharpening
            if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
                sharpenFilter.setValue(processedImage, forKey: kCIInputImageKey)
                sharpenFilter.setValue(0.7, forKey: kCIInputSharpnessKey)
                if let output = sharpenFilter.outputImage {
                    processedImage = output
                }
            }

            // 3. Noise reduction
            if let noiseFilter = CIFilter(name: "CINoiseReduction") {
                noiseFilter.setValue(processedImage, forKey: kCIInputImageKey)
                noiseFilter.setValue(0.02, forKey: "inputNoiseLevel")
                if let output = noiseFilter.outputImage {
                    processedImage = output
                }
            }

        case .gentle:
            // Minimal preprocessing for cursive/script fonts (preserve letter shapes)
            // 1. Gentle contrast (preserve letter connections)
            if let contrastFilter = CIFilter(name: "CIColorControls") {
                contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
                contrastFilter.setValue(1.15, forKey: kCIInputContrastKey) // Gentle contrast
                contrastFilter.setValue(1.05, forKey: kCIInputBrightnessKey) // Minimal brightness
                contrastFilter.setValue(0.8, forKey: kCIInputSaturationKey) // Reduce saturation slightly
                if let output = contrastFilter.outputImage {
                    processedImage = output
                }
            }

            // 2. Light unsharp mask (edge enhancement without artifacts)
            if let unsharpFilter = CIFilter(name: "CIUnsharpMask") {
                unsharpFilter.setValue(processedImage, forKey: kCIInputImageKey)
                unsharpFilter.setValue(0.3, forKey: kCIInputIntensityKey)
                unsharpFilter.setValue(2.5, forKey: kCIInputRadiusKey)
                if let output = unsharpFilter.outputImage {
                    processedImage = output
                }
            }

        case .colorBoost:
            // Boost colored text (red, orange, etc.) against backgrounds
            // 1. Increase saturation to make colored text pop
            if let contrastFilter = CIFilter(name: "CIColorControls") {
                contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
                contrastFilter.setValue(1.3, forKey: kCIInputContrastKey)
                contrastFilter.setValue(1.1, forKey: kCIInputBrightnessKey)
                contrastFilter.setValue(1.4, forKey: kCIInputSaturationKey) // Boost saturation
                if let output = contrastFilter.outputImage {
                    processedImage = output
                }
            }

            // 2. Vibrance boost (enhances less saturated colors more)
            if let vibranceFilter = CIFilter(name: "CIVibrance") {
                vibranceFilter.setValue(processedImage, forKey: kCIInputImageKey)
                vibranceFilter.setValue(0.5, forKey: "inputAmount")
                if let output = vibranceFilter.outputImage {
                    processedImage = output
                }
            }

            // 3. Moderate sharpening
            if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
                sharpenFilter.setValue(processedImage, forKey: kCIInputImageKey)
                sharpenFilter.setValue(0.4, forKey: kCIInputSharpnessKey)
                if let output = sharpenFilter.outputImage {
                    processedImage = output
                }
            }
        }

        // Convert back to UIImage
        guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Brightness Analysis for Neon/Illuminated Text Detection
    private func analyzeBrightness(in image: UIImage) -> [[Float]] {
        guard let cgImage = image.cgImage else { return [] }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                               width: width,
                               height: height,
                               bitsPerComponent: bitsPerComponent,
                               bytesPerRow: bytesPerRow,
                               space: colorSpace,
                               bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Create brightness map (downsampled for performance)
        let sampleSize = 20
        var brightnessMap: [[Float]] = []

        for y in stride(from: 0, to: height, by: sampleSize) {
            var row: [Float] = []
            for x in stride(from: 0, to: width, by: sampleSize) {
                let offset = (y * width + x) * bytesPerPixel
                if offset + 2 < pixelData.count {
                    let r = Float(pixelData[offset])
                    let g = Float(pixelData[offset + 1])
                    let b = Float(pixelData[offset + 2])
                    // Calculate perceived brightness
                    let brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                    row.append(brightness)
                }
            }
            if !row.isEmpty {
                brightnessMap.append(row)
            }
        }

        return brightnessMap
    }

    private func getBrightnessScore(for boundingBox: CGRect, brightnessMap: [[Float]], imageSize: CGSize) -> Float {
        guard !brightnessMap.isEmpty, !brightnessMap[0].isEmpty else { return 0.5 }

        // Convert normalized coordinates to brightness map coordinates
        let mapHeight = brightnessMap.count
        let mapWidth = brightnessMap[0].count

        // Vision coordinates are flipped (origin bottom-left)
        let centerX = Int(CGFloat(boundingBox.midX) * CGFloat(mapWidth))
        let centerY = Int((CGFloat(1.0) - CGFloat(boundingBox.midY)) * CGFloat(mapHeight))

        // Sample 3x3 grid around center
        var brightnessValues: [Float] = []
        for dy in -1...1 {
            for dx in -1...1 {
                let y = max(0, min(mapHeight - 1, centerY + dy))
                let x = max(0, min(mapWidth - 1, centerX + dx))
                brightnessValues.append(brightnessMap[y][x])
            }
        }

        // Return average brightness
        return brightnessValues.reduce(0, +) / Float(brightnessValues.count)
    }

    // MARK: - Result Selection with Alternatives
    private func selectBestResultWithAlternatives(from results: [(text: String, confidence: Float, size: CGFloat, boundingBox: CGRect, method: String)], brightnessMap: [[Float]], imageSize: CGSize) -> (bestResult: String?, candidates: [OCRCandidate]) {
        guard !results.isEmpty else { return (nil, []) }

        // Group by text content (case-insensitive)
        let grouped = Dictionary(grouping: results) { $0.text.lowercased() }

        // Score each unique text by multiple factors
        let scored = grouped.map { (text, occurrences) -> (text: String, score: Float, confidence: Float, debug: String) in
            let confidenceSum = occurrences.map { $0.confidence }.reduce(0, +)
            let avgConfidence = confidenceSum / Float(occurrences.count)

            let sizeSum = occurrences.map { Float($0.size) }.reduce(0, +)
            let avgSize = sizeSum / Float(occurrences.count)

            let methodCount = Float(occurrences.count)

            // Get brightness score for the bounding box
            let avgBoundingBox = occurrences.first!.boundingBox
            let brightnessScore = self.getBrightnessScore(for: avgBoundingBox, brightnessMap: brightnessMap, imageSize: imageSize)

            // Position score: prefer text in upper-center area (typical storefront location)
            // Vision coordinates: (0,0) is bottom-left, (1,1) is top-right
            let centerY = Float(avgBoundingBox.midY)
            let centerX = Float(avgBoundingBox.midX)

            // Ideal storefront position: upper 50% of image, horizontally centered
            let verticalScore: Float = centerY > 0.5 ? 1.0 : (centerY / 0.5)
            let horizontalDiff = abs(centerX - 0.5) * 2.0
            let horizontalScore: Float = 1.0 - horizontalDiff
            let positionScore = (verticalScore + horizontalScore) / 2.0

            // Enhanced brightness scoring for storefronts
            let brightnessBonus: Float = brightnessScore > 0.65 ? 0.5 : (brightnessScore > 0.5 ? 0.25 : 0.0)

            // Size bonus - storefronts are usually large text
            let sizeBonus: Float = avgSize > 0.02 ? 0.3 : (avgSize > 0.01 ? 0.15 : 0.0)

            // Weighted scoring
            let methodScore = methodCount * 0.20
            let confScore = avgConfidence * 0.15
            let sizeScore = avgSize * 0.20
            let posScore = positionScore * 0.20
            let brightScore = brightnessScore * 0.25

            let score = methodScore + confScore + sizeScore + posScore + brightScore + brightnessBonus + sizeBonus

            let debug = String(format: "conf:%.2f size:%.4f pos:%.2f bright:%.2f",
                             avgConfidence, avgSize, positionScore, brightnessScore)

            return (occurrences.first!.text, score, avgConfidence, debug)
        }

        // Sort by score
        let sortedScored = scored.sorted(by: { $0.score > $1.score })

        // Get top candidate
        let best = sortedScored.first?.text

        // Create candidate list (top 5 unique options)
        let candidates = sortedScored.prefix(5).map { item in
            OCRCandidate(text: item.text, score: item.score, confidence: item.confidence)
        }

        // Log top 3 candidates with scores for debugging
        print("\n🏆 TOP CANDIDATES:")
        for (index, item) in sortedScored.prefix(3).enumerated() {
            print("   \(index + 1). \"\(item.text)\" - score: \(String(format: "%.3f", item.score)) (\(item.debug))")
        }

        return (best, candidates)
    }

    // MARK: - Result Selection Algorithm (Enhanced with Brightness + Position) - DEPRECATED
    private func selectBestResult(from results: [(text: String, confidence: Float, size: CGFloat, boundingBox: CGRect, method: String)], brightnessMap: [[Float]], imageSize: CGSize) -> String? {
        let (best, _) = selectBestResultWithAlternatives(from: results, brightnessMap: brightnessMap, imageSize: imageSize)
        return best
    }

    // MARK: - Logging for Daily Testing
    private func logOCRResults(_ results: [(text: String, confidence: Float, size: CGFloat, boundingBox: CGRect, method: String)], bestResult: String?) {
        print("\n" + String(repeating: "=", count: 60))
        print("📊 OCR RESULTS SUMMARY")
        print(String(repeating: "=", count: 60))

        // Group by method
        let byMethod = Dictionary(grouping: results) { $0.method }

        for (method, items) in byMethod.sorted(by: { $0.key < $1.key }) {
            print("\n🔍 \(method.uppercased()) OCR:")
            for item in items.sorted(by: { $0.confidence > $1.confidence }).prefix(5) {
                let pos = String(format: "pos:(%.2f,%.2f)", item.boundingBox.midX, item.boundingBox.midY)
                print("   • \"\(item.text)\" (conf: \(String(format: "%.2f", item.confidence)), size: \(String(format: "%.4f", item.size)), \(pos))")
            }
        }

        print("\n✅ SELECTED RESULT: \(bestResult ?? "nil")")
        print(String(repeating: "=", count: 60) + "\n")
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
}

// Photo Preview Info Sheet
struct PhotoPreviewInfoSheet: View {
    let image: UIImage
    let locationManager: LocationManager
    let isLoadingData: Bool
    let extractedText: String?
    let city: String?
    let state: String?
    let country: String?
    let address: String?
    let phoneNumber: String?
    let category: String?
    let locationText: String
    let onRetake: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isLoadingData {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding(.top, 40)

                    Text("Getting place information...")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Content loaded
                contentView
            }
        }
    }

    var contentView: some View {
        VStack(spacing: 0) {
            // Top bar with retake, title, and done buttons
            HStack(spacing: 16) {
                // Retake button (left)
                Button(action: onRetake) {
                    Text("Retake")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(.leading, 20)

                VStack(spacing: 2) {
                    if let extractedText = extractedText, !extractedText.isEmpty {
                        Text(extractedText)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)

                // Done button (right)
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Full address above direction button
                    VStack(alignment: .leading, spacing: 4) {
                        // Street address
                        if let address = address, !address.isEmpty {
                            Text(address)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }

                        // City, State, Country
                        Text(locationText)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }

                    // Call and Get direction buttons
                    HStack(spacing: 12) {
                        // Call button (if phone number available)
                        if let phoneNumber = phoneNumber, !phoneNumber.isEmpty {
                            Button(action: {
                                if let url = URL(string: "tel://\(phoneNumber.replacingOccurrences(of: " ", with: ""))") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 54)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        }

                        // Get direction button
                        Button(action: {
                            openInMaps()
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 18))
                                Text("Get direction")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    }

                    // Details section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)

                        // Category
                        if let category = category {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundColor(.secondary)
                                Text(category)
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Timestamp
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text(Date().formatted(date: .long, time: .shortened))
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    func openInMaps() {
        guard let location = locationManager.currentLocation else { return }

        let coordinate = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)

        // Set the name to extracted text or location text
        if let extractedText = extractedText, !extractedText.isEmpty {
            mapItem.name = extractedText
        } else {
            mapItem.name = locationText
        }

        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// Camera Manager
class CameraManager: NSObject, ObservableObject {
    @Published var isFlashOn = false
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!
    @Published var zoomScale: CGFloat = 1.0

    var currentCamera: AVCaptureDevice.Position = .back
    var currentDevice: AVCaptureDevice?
    var onPhotoCaptured: ((UIImage) -> Void)?

    private var minZoom: CGFloat = 1.0
    private var maxZoom: CGFloat = 5.0

    func setupCamera() {
        checkPermissions()
    }

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setUp()
                    }
                }
            }
        default:
            print("Camera permission denied")
        }
    }

    func setUp() {
        do {
            session.beginConfiguration()

            // Try to get ultra wide camera first for 0.5x support
            let device: AVCaptureDevice?

            if let dualWideCamera = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: currentCamera) {
                // iPhone 11 Pro and later (supports 0.5x)
                device = dualWideCamera
            } else if let ultraWideCamera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: currentCamera) {
                // Fallback to ultra wide
                device = ultraWideCamera
            } else {
                // Fallback to regular wide angle
                device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCamera)
            }

            guard let device = device else {
                print("❌ No camera available")
                return
            }

            currentDevice = device
            minZoom = device.minAvailableVideoZoomFactor
            maxZoom = min(device.maxAvailableVideoZoomFactor, 10.0)

            print("📷 Camera zoom range: \(minZoom)x - \(maxZoom)x")

            let input = try AVCaptureDeviceInput(device: device)

            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.commitConfiguration()

            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        } catch {
            print("❌ Camera setup error: \(error.localizedDescription)")
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()

        if isFlashOn {
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }

        output.capturePhoto(with: settings, delegate: self)
    }

    func toggleFlash() {
        isFlashOn.toggle()
    }

    func flipCamera() {
        session.stopRunning()

        session.inputs.forEach { input in
            session.removeInput(input)
        }

        currentCamera = currentCamera == .back ? .front : .back
        zoomScale = 1.0

        setUp()
    }

    func stopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
            }
        }
    }

    func zoom(factor: CGFloat) {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()

            let zoom = max(minZoom, min(factor, maxZoom))
            device.videoZoomFactor = zoom
            zoomScale = zoom

            device.unlockForConfiguration()
        } catch {
            print("❌ Zoom error: \(error.localizedDescription)")
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("❌ Photo capture error: \(error!.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("❌ Failed to convert photo data")
            return
        }

        DispatchQueue.main.async {
            self.onPhotoCaptured?(image)
        }
    }
}

// Camera Preview
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)

        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview.frame = view.frame
        camera.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(camera.preview)

        // Add pinch gesture for zoom
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {

    }

    func makeCoordinator() -> Coordinator {
        Coordinator(camera: camera)
    }

    class Coordinator: NSObject {
        let camera: CameraManager
        var lastScale: CGFloat = 1.0

        init(camera: CameraManager) {
            self.camera = camera
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .began {
                lastScale = camera.zoomScale
            }

            let newScale = lastScale * gesture.scale
            camera.zoom(factor: newScale)
        }
    }
}
