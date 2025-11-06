# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS application built with SwiftUI and SwiftData, targeting iOS 26.0. The app is named "places" (bundle ID: expenai.places) and appears to be a location/places tracking application in its initial stages. Currently, it has a basic SwiftData persistence setup with a simple Item model.

## Build and Run

### Building the Project
```bash
# Build for iOS simulator
xcodebuild -project places.xcodeproj -scheme places -sdk iphonesimulator -configuration Debug build

# Build for device (requires signing)
xcodebuild -project places.xcodeproj -scheme places -sdk iphoneos -configuration Debug build

# Clean build artifacts
xcodebuild clean -project places.xcodeproj -scheme places
```

### Running in Xcode
Open `places.xcodeproj` in Xcode and use the standard Xcode build/run commands (Cmd+R).

## Project Configuration

- **Development Team**: R3BH487556
- **Bundle Identifier**: expenai.places
- **Swift Version**: 5.0
- **Minimum iOS Version**: 26.0
- **Supported Devices**: iPhone and iPad
- **App Category**: Books (public.app-category.books)

### Build Settings Notes
- SwiftUI Previews are enabled (`ENABLE_PREVIEWS = YES`)
- Main Actor isolation is enabled by default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- String catalog symbol generation is enabled

## Architecture

### Data Persistence
The app uses **SwiftData** for persistence with the following architecture:

- **ModelContainer Setup**: Initialized in `placesApp.swift:13-24` as a shared container
- **Schema**: Currently contains only the `Item` model
- **Storage**: Persistent storage (not in-memory)
- **Access**: Models are accessed via `@Environment(\.modelContext)` in views

### Core Components

1. **placesApp.swift** - Main app entry point
   - Sets up the SwiftData ModelContainer
   - Configures the root WindowGroup with ContentView
   - Injects the modelContainer into the environment

2. **Item.swift** - SwiftData model
   - Simple model with a single `timestamp: Date` property
   - Marked with `@Model` macro for SwiftData

3. **ContentView.swift** - Main view
   - Uses `@Query` to fetch Items from SwiftData
   - Implements NavigationSplitView pattern
   - Supports add/delete operations with animations

### SwiftData Query Pattern
Views use `@Query private var items: [Item]` to automatically fetch and observe data changes. The modelContext is accessed via `@Environment(\.modelContext)` for insert/delete operations.

## Development Patterns

### Adding New Models
When adding new SwiftData models:
1. Create the model class and mark it with `@Model`
2. Add the model to the schema in `placesApp.swift:14-16`
3. Use `@Query` in views to fetch data
4. Use `modelContext.insert()` and `modelContext.delete()` for mutations

### SwiftUI Previews
All views should include `#Preview` blocks. For SwiftData models, use:
```swift
#Preview {
    YourView()
        .modelContainer(for: YourModel.self, inMemory: true)
}
```
