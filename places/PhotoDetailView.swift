//
//  PhotoDetailView.swift
//  places
//
//  Created by Amarpreet Singh on 11/6/25.
//

import SwiftUI
import SwiftData
import MapKit

struct PhotoDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CapturedPhoto.timestamp, order: .reverse) private var allPhotos: [CapturedPhoto]
    let photo: CapturedPhoto
    @State private var showDeleteConfirmation = false
    @State private var showInfoSheet = true
    @State private var dragOffset: CGFloat = 0

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
            .presentationDetents([.height(300), .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
            .interactiveDismissDisabled()
        }
        .alert("Delete this place?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePhoto()
            }
        } message: {
            Text("This photo will be permanently deleted.")
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
    let photo: CapturedPhoto
    let locationText: String
    @Binding var showDeleteConfirmation: Bool
    let onDelete: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with share, title, and close buttons
            HStack(spacing: 16) {
                Button(action: {
                    print("Share button tapped")
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                        .frame(width: 50, height: 50)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }

                VStack(spacing: 2) {
                    if let extractedText = photo.extractedText, !extractedText.isEmpty {
                        Text(extractedText)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
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
                        Text(locationText)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
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

                // Details section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Details")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)

                    // Timestamp
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text(photo.timestamp.formatted(date: .long, time: .shortened))
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }

                    // Coordinates
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.6f, %.6f", photo.latitude, photo.longitude))
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }

                    // Altitude
                    HStack {
                        Image(systemName: "mountain.2")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f m", photo.altitude))
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
