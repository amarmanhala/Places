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
    @State private var selectedCategory: String?
    @State private var showProfile = false
    @State private var showSearch = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var groupedPhotos: [String: [CapturedPhoto]] {
        Dictionary(grouping: photos) { photo in
            photo.category ?? "Other"
        }
    }

    var sortedCategories: [String] {
        groupedPhotos.keys.sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TabView(selection: $selectedTab) {
                    collectionView
                        .tabItem {
                            Image(systemName: "square.stack.3d.up")
                            Text("Collection")
                        }
                        .tag(0)

                    photosGrid
                        .tabItem {
                            Image(systemName: "photo")
                            Text("All")
                        }
                        .tag(1)
                }

                // Floating Search Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 80) // Above tab bar
                    }
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
            .sheet(item: $selectedCategory) { category in
                CategoryPhotosView(category: category, photos: groupedPhotos[category] ?? [], selectedPhoto: $selectedPhoto)
            }
            .sheet(isPresented: $showSearch) {
                SearchView(photos: photos, selectedPhoto: $selectedPhoto)
            }
        }
    }

    // ✅ Collection View
    @ViewBuilder
    var collectionView: some View {
        if photos.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)

                Text("No collections yet")
                    .font(.title2)
                    .foregroundColor(.gray)

                Text("Capture photos to see them organized by category")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(sortedCategories, id: \.self) { category in
                        CategoryCard(
                            category: category,
                            photos: groupedPhotos[category] ?? [],
                            onTap: {
                                selectedCategory = category
                            }
                        )
                    }
                }
                .padding(8)
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

// Category Card Component
struct CategoryCard: View {
    let category: String
    let photos: [CapturedPhoto]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Hero Image
                if let firstPhoto = photos.first,
                   let uiImage = UIImage(data: firstPhoto.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .cornerRadius(12)
                }

                // Gradient overlay for text readability
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.7),
                        Color.black.opacity(0.3),
                        Color.clear
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 200)
                .cornerRadius(12)

                // Category Name and Count
                VStack(alignment: .leading, spacing: 4) {
                    Text(category)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text("\(photos.count)")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(16)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Category Photos View
struct CategoryPhotosView: View {
    @Environment(\.dismiss) var dismiss
    let category: String
    let photos: [CapturedPhoto]
    @Binding var selectedPhoto: CapturedPhoto?

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
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
                                    dismiss()
                                }
                        }
                    }
                }
            }
            .navigationTitle(category)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Make String Identifiable for sheet presentation
extension String: Identifiable {
    public var id: String { self }
}

// Search View
struct SearchView: View {
    @Environment(\.dismiss) var dismiss
    let photos: [CapturedPhoto]
    @Binding var selectedPhoto: CapturedPhoto?

    @State private var searchText = ""

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var filteredPhotos: [CapturedPhoto] {
        if searchText.isEmpty {
            return photos
        } else {
            return photos.filter { photo in
                let searchLower = searchText.lowercased()

                if let text = photo.extractedText?.lowercased(), text.contains(searchLower) {
                    return true
                }
                if let category = photo.category?.lowercased(), category.contains(searchLower) {
                    return true
                }
                if let city = photo.city?.lowercased(), city.contains(searchLower) {
                    return true
                }
                if let state = photo.state?.lowercased(), state.contains(searchLower) {
                    return true
                }
                if let country = photo.country?.lowercased(), country.contains(searchLower) {
                    return true
                }
                if let address = photo.address?.lowercased(), address.contains(searchLower) {
                    return true
                }

                return false
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredPhotos.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        if searchText.isEmpty {
                            Text("Search for places")
                                .font(.title2)
                                .foregroundColor(.gray)

                            Text("Try searching by name, location, or category")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            Text("No results for '\(searchText)'")
                                .font(.title2)
                                .foregroundColor(.gray)

                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(filteredPhotos, id: \.timestamp) { photo in
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
                                            dismiss()
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search places...")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
