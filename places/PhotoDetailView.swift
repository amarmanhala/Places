//
//  PhotoDetailView.swift
//  places
//
//  Created by Amarpreet Singh on 11/6/25.
//

import SwiftUI
import SwiftData

struct PhotoDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \CapturedPhoto.timestamp, order: .reverse) private var allPhotos: [CapturedPhoto]
    let photo: CapturedPhoto
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
        TabView {
            // Get Direction Tab
            NavigationStack {
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    if let uiImage = UIImage(data: photo.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .ignoresSafeArea()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Places")
                            }
                            .foregroundColor(.white)
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(locationText)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(photo.timestamp, format: .dateTime.hour().minute())
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            print("Action button tapped")
                        }) {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .tabItem {
                Label("Get direction", systemImage: "location.fill")
            }

            // Share Tab
            NavigationStack {
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    if let uiImage = UIImage(data: photo.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .ignoresSafeArea()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Places")
                            }
                            .foregroundColor(.white)
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(locationText)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(photo.timestamp, format: .dateTime.hour().minute())
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            print("Action button tapped")
                        }) {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .tabItem {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .tabViewBottomAccessory {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 2) {
                    Text(locationText)
                        .font(.headline)
                    Text(photo.timestamp, format: .dateTime.month().day().year())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
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
    }
}
