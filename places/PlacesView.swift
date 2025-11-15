//
//  PlacesView.swift
//  places
//

import SwiftUI
import SwiftData
import Speech

// MARK: - PlacesTabs
enum PlacesTabs: Int {
    case all = 0
    case collection = 1
}

// MARK: - PlacesView (main)
struct PlacesView: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \CapturedPhoto.timestamp, order: .reverse) private var photos: [CapturedPhoto]

    @State private var selectedTab: PlacesTabs = .all
    @State private var searchText = ""
    @State private var selectedPhoto: CapturedPhoto?
    @State private var selectedCategory: String?
    @State private var isSearchActive = false
    @State private var showFeedback = false
    @StateObject private var voiceSearch = VoiceSearchManager()

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
        TabView(selection: $selectedTab) {

            // MARK: - ALL TAB
            NavigationStack {
                photosGrid
                    .navigationTitle("Places")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button { dismiss() } label: {
                                Image(systemName: "chevron.left")
                            }
                        }
                        // Feedback button
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showFeedback = true
                            } label: {
                                Image(systemName: "exclamationmark.bubble")
                            }
                        }
                        // Search button
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                isSearchActive = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "photo")
                Text("All")
            }
            .tag(PlacesTabs.all)

            // MARK: - COLLECTION TAB
            NavigationStack {
                collectionView
                    .navigationTitle("Places")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button { dismiss() } label: {
                                Image(systemName: "chevron.left")
                            }
                        }
                        // Feedback button
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showFeedback = true
                            } label: {
                                Image(systemName: "exclamationmark.bubble")
                            }
                        }
                        // Search button
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                isSearchActive = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                    }
            }
            .tabItem {
                Image(systemName: "square.stack.3d.up")
                Text("Collections")
            }
            .tag(PlacesTabs.collection)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.primary)
        .onChange(of: selectedTab) { oldValue, newValue in
            // Soft haptic feedback on tab change
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.impactOccurred()
        }
        // Present SearchScreen as a sheet
        .sheet(isPresented: $isSearchActive) {
            NavigationStack {
                SearchScreen(
                    searchText: $searchText,
                    isSearchActive: $isSearchActive,
                    photos: photos,
                    selectedPhoto: $selectedPhoto,
                    voiceSearch: voiceSearch
                )
            }
            .presentationDetents([.large, .medium])
        }
        // Present Feedback sheet
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
        // Photo detail presentation
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
        // Category sheet
        .sheet(item: $selectedCategory) { category in
            CategoryPhotosView(
                category: category,
                photos: groupedPhotos[category] ?? [],
                selectedPhoto: $selectedPhoto
            )
        }
    }

    // MARK: - Photos Grid View
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
                                .onTapGesture { selectedPhoto = photo }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Collection View
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
                            onTap: { selectedCategory = category }
                        )
                    }
                }
                .padding(8)
            }
        }
    }
}

// MARK: - SearchScreen (moved out as sheet)
struct SearchScreen: View {
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    var photos: [CapturedPhoto]
    @Binding var selectedPhoto: CapturedPhoto?
    @ObservedObject var voiceSearch: VoiceSearchManager

    @FocusState private var isSearchFocused: Bool

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    // Derived properties
    var groupedPhotos: [String: [CapturedPhoto]] {
        Dictionary(grouping: photos) { $0.category ?? "Other" }
    }

    var body: some View {
        searchView
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search your places...")
            .task {
                // Auto-focus search field when sheet appears
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                isSearchFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        searchText = ""
                        isSearchActive = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: handleVoiceSearch) {
                        Image(systemName: voiceSearch.isListening ? "mic.fill" : "mic")
                            .foregroundColor(voiceSearch.isListening ? .red : .primary)
                    }
                }
            }
    }

    @ViewBuilder
    var searchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                if searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recents")
                            .font(.system(size: 28, weight: .bold))
                            .padding(.horizontal, 20)

                        HStack(spacing: 12) {
                            ForEach(Array(photos.prefix(3)), id: \.timestamp) { photo in
                                if let uiImage = UIImage(data: photo.imageData) {
                                    VStack(spacing: 8) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 110, height: 110)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .onTapGesture { selectedPhoto = photo }

                                        Text(photo.extractedText ?? "Unknown")
                                            .font(.system(size: 13))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 110)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)

                } else {
                    let filtered = photos.filter { photo in
                        (photo.extractedText ?? "").localizedCaseInsensitiveContains(searchText) ||
                        (photo.category ?? "").localizedCaseInsensitiveContains(searchText) ||
                        (photo.address ?? "").localizedCaseInsensitiveContains(searchText) ||
                        (photo.city ?? "").localizedCaseInsensitiveContains(searchText) ||
                        (photo.state ?? "").localizedCaseInsensitiveContains(searchText) ||
                        (photo.country ?? "").localizedCaseInsensitiveContains(searchText)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(filtered.count) Results")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(filtered, id: \.timestamp) { photo in
                                if let uiImage = UIImage(data: photo.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: UIScreen.main.bounds.width / 3 - 2,
                                               height: UIScreen.main.bounds.width / 3 - 2)
                                        .clipped()
                                        .onTapGesture { selectedPhoto = photo }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Voice search helper
    func handleVoiceSearch() {
        if voiceSearch.authorizationStatus == .notDetermined {
            voiceSearch.requestAuthorization()
            return
        }

        guard voiceSearch.authorizationStatus == .authorized else {
            print("❌ Speech recognition not authorized")
            return
        }

        voiceSearch.toggleListening { transcription in
            DispatchQueue.main.async {
                self.searchText = transcription
            }
        }
    }
}

// MARK: - CategoryCard (unchanged)
struct CategoryCard: View {
    let category: String
    let photos: [CapturedPhoto]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                if let first = photos.first,
                   let img = UIImage(data: first.imageData) {
                    Image(uiImage: img)
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

                LinearGradient(
                    gradient: Gradient(colors: [
                        .black.opacity(0.7),
                        .black.opacity(0.3),
                        .clear
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 200)
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(category)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(photos.count)")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CategoryPhotosView (unchanged)
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
                        if let img = UIImage(data: photo.imageData) {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: UIScreen.main.bounds.width / 3 - 2,
                                       height: UIScreen.main.bounds.width / 3 - 2)
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
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension String: Identifiable {
    public var id: String { self }
}
