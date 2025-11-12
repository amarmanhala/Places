//
//  PhotoDetailView.swift
//  places
//
//  Created by Amarpreet Singh on 11/6/25.
//

import SwiftUI
import SwiftData
import MapKit

// Import DEBUG_OCR flag
// (Defined in OCRLogger.swift)

struct PhotoDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CapturedPhoto.timestamp, order: .reverse) private var allPhotos: [CapturedPhoto]
    let photo: CapturedPhoto
    @State private var showDeleteConfirmation = false
    @State private var showInfoSheet = true
    @State private var dragOffset: CGFloat = 0
    @State private var selectedDetent: PresentationDetent = .height(300)

    var locationText: String {
        if let city = photo.city, let country = photo.country {
            if let state = photo.state {
                return "\(city), \(state), \(country)"
            } else {
                return "\(city), \(country)"
            }
        } else {
            return "Location not available"
        }
    }

    var body: some View {
        ZStack {
            // Full screen image
            Color.black
                .ignoresSafeArea()

            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            }

        }
        .offset(y: dragOffset)
        .scaleEffect(1 - (dragOffset / 1000))
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .sheet(isPresented: $showInfoSheet) {
            PhotoInfoSheet(
                photo: photo,
                locationText: locationText,
                showDeleteConfirmation: $showDeleteConfirmation,
                onDelete: deletePhoto,
                onDismiss: { dismiss() }
            )
            .presentationDetents([.height(90), .height(300), .large], selection: $selectedDetent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
            .interactiveDismissDisabled()
            .alert("Delete this place?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deletePhoto()
                }
            } message: {
                Text("This photo will be permanently deleted.")
            }
        }
    }

    func deletePhoto() {
        modelContext.delete(photo)
        do {
            try modelContext.save()
            print("✅ Photo deleted successfully")
        } catch {
            print("❌ Error deleting photo: \(error)")
        }
        dismiss()
    }
}

struct PhotoInfoSheet: View {
    @Environment(\.modelContext) private var modelContext
    let photo: CapturedPhoto
    let locationText: String
    @Binding var showDeleteConfirmation: Bool
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @State private var showShareSheet = false
    @State private var showEditSheet = false
    @State private var editedText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with share, title, and close buttons
            HStack(spacing: 16) {
                Button(action: {
                    showShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                        .frame(width: 50, height: 50)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }

                VStack(spacing: 4) {
                    if let extractedText = photo.extractedText, !extractedText.isEmpty {
                        Text(extractedText)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    // DEBUG: OCR Testing buttons
                    if DEBUG_OCR {
                        HStack(spacing: 8) {
                            Button(action: {
                                markAsCorrect()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Correct")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                            }

                            Button(action: {
                                editedText = photo.extractedText ?? ""
                                showEditSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Edit")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Button(action: {
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 50, height: 50)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Full address above direction button
                    VStack(alignment: .leading, spacing: 4) {
                        // Street address
                        if let address = photo.address, !address.isEmpty {
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
                    if let phoneNumber = photo.phoneNumber, !phoneNumber.isEmpty {
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
                    if let category = photo.category {
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
                        Text(photo.timestamp.formatted(date: .long, time: .shortened))
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }

                    // Delete button
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Photo")
                        }
                        .foregroundColor(.red)
                        .font(.system(size: 15, weight: .medium))
                    }
                    .padding(.top, 8)
                }
            }
            .padding(24)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = UIImage(data: photo.imageData) {
                ShareSheet(items: shareItems, image: image)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Edit Place Name")
                        .font(.title2.bold())
                        .padding(.top)

                    TextField("Place name", text: $editedText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    Button(action: {
                        saveEdit()
                    }) {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(editedText.isEmpty)

                    Spacer()
                }
                .padding()
                .navigationBarItems(
                    trailing: Button("Cancel") {
                        showEditSheet = false
                    }
                )
            }
            .presentationDetents([.height(300)])
        }
    }

    func markAsCorrect() {
        if let originalText = photo.extractedText {
            // Log that OCR was correct
            OCRLogger.shared.logCorrection(originalText: originalText, correctedText: originalText)
            print("✅ Marked '\(originalText)' as correct")
        }
    }

    func saveEdit() {
        let originalText = photo.extractedText ?? ""

        // Update the photo's extracted text
        photo.extractedText = editedText

        // Save to database
        do {
            try modelContext.save()
            print("✅ Place name updated to: \(editedText)")
        } catch {
            print("❌ Error saving edit: \(error)")
        }

        // Log the correction for OCR analysis
        OCRLogger.shared.logCorrection(originalText: originalText, correctedText: editedText)

        showEditSheet = false
    }

    var shareItems: [Any] {
        var items: [Any] = []

        // Add image
        if let image = UIImage(data: photo.imageData) {
            items.append(image)
        }

        // Build share text
        var shareText = ""

        // Add place name
        if let extractedText = photo.extractedText, !extractedText.isEmpty {
            shareText += "\(extractedText)\n\n"
        }

        // Add address
        if let address = photo.address, !address.isEmpty {
            shareText += "\(address)\n"
        }
        shareText += "\(locationText)\n\n"

        // Add Maps link
        let mapsURL = "http://maps.apple.com/?ll=\(photo.latitude),\(photo.longitude)"
        if let extractedText = photo.extractedText, !extractedText.isEmpty {
            shareText += "View in Maps: \(mapsURL)&q=\(extractedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? extractedText)"
        } else {
            shareText += "View in Maps: \(mapsURL)"
        }

        items.append(shareText)

        return items
    }

    func openInMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: photo.latitude, longitude: photo.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)

        // Set the name to extracted text or location text
        if let extractedText = photo.extractedText, !extractedText.isEmpty {
            mapItem.name = extractedText
        } else {
            mapItem.name = locationText
        }

        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// Share Sheet UIViewControllerRepresentable
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
