//
//  ContentView.swift
//  places
//
//  Created by Amarpreet Singh on 11/5/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var capturedLocation: CLLocation?
    @State private var showPlaces = false

    var body: some View {
        ZStack {
            Text("Hello Amar")
                .foregroundColor(.white)

            if showCamera {
                ZStack {
                    CameraView(capturedImage: $capturedImage, capturedLocation: $capturedLocation, modelContext: modelContext)
                        .edgesIgnoringSafeArea(.all)
                        .onChange(of: capturedImage) { oldValue, newValue in
                            // Reset captured image immediately to go back to camera
                            if newValue != nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    capturedImage = nil
                                    capturedLocation = nil
                                    showCamera = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        showCamera = true
                                    }
                                }
                            }
                        }

                    // Places button at top left aligned with flash button
                    VStack {
                        HStack {
                            Button(action: {
                                showPlaces = true
                            }) {
                                Text("Places")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                            .padding(.top, 60)
                            .padding(.leading)

                            Spacer()
                        }

                        Spacer()
                    }
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            showCamera = true
        }
        .fullScreenCover(isPresented: $showPlaces) {
            PlacesView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
