//
//  FeedbackView.swift
//  places
//
//  Created by Claude Code
//

import SwiftUI
import MessageUI

struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @State private var feedbackText = ""
    @State private var showMailError = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 200)
                        .autocapitalization(.sentences)
                        .focused($isFocused)
                } header: {
                    Text("Your Feedback")
                } footer: {
                    Text("Your feedback helps us improve the app. We read every message.")
                        .font(.caption)
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sendFeedback()
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task {
                // Auto-focus text editor when sheet appears
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                isFocused = true
            }
            .alert("Email Not Available", isPresented: $showMailError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please configure an email account on your device to send feedback.")
            }
        }
    }

    private func sendFeedback() {
        let email = "amar.manhala@gmail.com"
        let subject = "Places App Feedback"
        let body = feedbackText

        let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let url = URL(string: "mailto:\(email)?subject=\(subjectEncoded)&body=\(bodyEncoded)") else {
            showMailError = true
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { success in
                if success {
                    dismiss()
                } else {
                    showMailError = true
                }
            }
        } else {
            showMailError = true
        }
    }
}

#Preview {
    FeedbackView()
}
