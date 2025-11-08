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

    @State private var selectedTab = 0
    @State private var selectedPhoto: CapturedPhoto?
    @State private var showProfile = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                
                // ✅ Collection Tab
                photosGrid
                    .tag(0)
                    .tabItem {
                        Label("Collection", systemImage: "square.stack.3d.up.fill")
                    }
                
                // ✅ All Tab
                photosGrid
                    .tag(1)
                    .tabItem {
                        Label("All", systemImage: "photo.on.rectangle.angled")
                    }
            }
            .navigationTitle("Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
                // Back Button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }

                // Profile Button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person")
                    }
                }
            }
            .fullScreenCover(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
        }
    }

    // ✅ Extracted Photos Grid View
    @ViewBuilder
    var photosGrid: some View {
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
                                .frame(
                                    width: UIScreen.main.bounds.width / 3 - 2,
                                    height: UIScreen.main.bounds.width / 3 - 2
                                )
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
}
