//
//  PlacesView.swift
//  places
//
//  Created by Amarpreet Singh on 11/6/25.
//

import SwiftUI
import SwiftData

struct PlacesView: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \CapturedPhoto.timestamp, order: .reverse) private var photos: [CapturedPhoto]
    @State private var selectedPhoto: CapturedPhoto?

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        TabView {
            // Collection Tab
            NavigationStack {
                ZStack {
                    if photos.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text("No photos yet")
                                .font(.title2)
                                .foregroundColor(.gray)

                            Text("Capture photos to see them here")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(photos, id: \.timestamp) { photo in
                                    if let uiImage = UIImage(data: photo.imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: UIScreen.main.bounds.width / 3 - 2, height: UIScreen.main.bounds.width / 3 - 2)
                                            .clipped()
                                            .onTapGesture {
                                                selectedPhoto = photo
                                            }
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Place")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            // Share button
                            print("Share button tapped")
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                }
                .fullScreenCover(item: $selectedPhoto) { photo in
                    PhotoDetailView(photo: photo)
                }
            }
            .tabItem {
                Label("Collection", systemImage: "square.stack.3d.up.fill")
            }

            // All Tab
            NavigationStack {
                ZStack {
                    if photos.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text("No photos yet")
                                .font(.title2)
                                .foregroundColor(.gray)

                            Text("Capture photos to see them here")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(photos, id: \.timestamp) { photo in
                                    if let uiImage = UIImage(data: photo.imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: UIScreen.main.bounds.width / 3 - 2, height: UIScreen.main.bounds.width / 3 - 2)
                                            .clipped()
                                            .onTapGesture {
                                                selectedPhoto = photo
                                            }
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Place")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            // Share button
                            print("Share button tapped")
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                }
                .fullScreenCover(item: $selectedPhoto) { photo in
                    PhotoDetailView(photo: photo)
                }
            }
            .tabItem {
                Label("All", systemImage: "photo.on.rectangle.angled")
            }
        }
    }
}

#Preview {
    PlacesView()
}
