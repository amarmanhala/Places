//
//  OnboardingView.swift
//  places
//
//  Created by Amarpreet Singh on 11/9/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    Text("to Places")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

                // Description
                Text("Capture and organize your favorite places with photos, locations, and memories.")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)

                // Feature 1
                HStack(alignment: .top, spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Capture Places")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Take photos of storefronts and the app automatically extracts the name and location.")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

                // Feature 2
                HStack(alignment: .top, spacing: 20) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Organize & Navigate")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Browse your places by category and get directions whenever you need them.")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

                // Feature 3
                HStack(alignment: .top, spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Privacy Matters")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        Text("All your photos and location data are stored locally on your device.")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)

                Spacer()

                // Continue Button
                Button(action: {
                    showOnboarding = false
                }) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(30)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

                
               
            }
        }
    }
}
