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
                    Button(action: {
                        showPlacesView = true
                    }) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color(uiColor: .systemGray6))
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
                            .background(Color(uiColor: .systemGray6))
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
    @State private var extractedText: String?
    @State private var city: String?
    @State private var state: String?
    @State private var country: String?
    @State private var address: String?
    @State private var phoneNumber: String?
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
                extractedText: extractedText,
                city: city,
                state: state,
                country: country,
                address: address,
                phoneNumber: phoneNumber,
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
                searchNearbyStore(storeName: storeName, nearLocation: location) { storeLocation, verifiedName, foundCity, foundState, foundCountry, foundAddress, foundPhone in
                    DispatchQueue.main.async {
                        if storeLocation != nil {
                            self.extractedText = verifiedName ?? text
                            self.city = foundCity
                            self.state = foundState
                            self.country = foundCountry
                            self.address = foundAddress
                            self.phoneNumber = foundPhone
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
        guard let location = locationManager.currentLocation else { return }

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

                searchNearbyStore(storeName: storeName, nearLocation: location) { storeLocation, verifiedName, city, state, country, address, phoneNumber in
                    let finalLocation = storeLocation ?? location
                    let finalName = verifiedName ?? extractedText

                    if storeLocation != nil {
                        // Store found! Use its data
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
                            extractedText: finalName
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
                extractedText: extractedText
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

    func searchNearbyStore(storeName: String, nearLocation: CLLocation, completion: @escaping (CLLocation?, String?, String?, String?, String?, String?, String?) -> Void) {
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
                completion(nil, nil, nil, nil, nil, nil, nil)
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

                if let phone = phoneNumber {
                    print("📞 Phone: \(phone)")
                }

                completion(storeLocation, verifiedName, city, state, country, fullAddress, phoneNumber)
            } else {
                completion(nil, nil, nil, nil, nil, nil, nil)
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

            let recognizedTexts = observations.compactMap { observation -> (text: String, confidence: Float, size: CGFloat)? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence > 0.5 else {
                    return nil
                }

                let boundingBox = observation.boundingBox
                let size = boundingBox.width * boundingBox.height

                return (candidate.string, candidate.confidence, size)
            }

            let sortedTexts = recognizedTexts
                .sorted { $0.size > $1.size }
                .map { $0.text }

            print("📝 All recognized text: \(sortedTexts)")

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
    let extractedText: String?
    let city: String?
    let state: String?
    let country: String?
    let address: String?
    let phoneNumber: String?
    let locationText: String
    let onRetake: () -> Void
    let onDone: () -> Void

    var body: some View {
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

                        // Timestamp
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text(Date().formatted(date: .long, time: .shortened))
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }

                        // Coordinates
                        if let location = locationManager.currentLocation {
                            HStack {
                                Image(systemName: "location")
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude))
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }

                            // Altitude
                            HStack {
                                Image(systemName: "mountain.2")
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f m", location.altitude))
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
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
