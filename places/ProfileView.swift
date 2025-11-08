import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {

                // ✅ Account Section
                Section(header: Text("Account").textCase(nil)) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.primary) // icon black
                            .frame(width: 24)

                        Text("Email")
                            .foregroundColor(.primary) // label black

                        Spacer()

                        Text("user@example.com")
                            .foregroundColor(.secondary) // gray
                    }
                }

                // ✅ Logout Section
                Section {
                    Button(action: {
                        print("Logout tapped")
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                                .frame(width: 24)

                            Text("Logout")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(.primary) // black
                    }
                }
            }
            // ✅ Disable default blue tint for entire screen
            .tint(.primary)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
