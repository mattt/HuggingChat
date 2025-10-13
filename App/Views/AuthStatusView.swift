import SwiftUI

struct AuthStatusView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.openURL) private var openURL
    @State private var showSignOutConfirmation = false

    var body: some View {
        VStack(spacing: 12) {
            if authManager.isAuthenticated {
                // Authenticated state
                HStack(spacing: 12) {
                    Button {
                        if let user = authManager.currentUser,
                            let username = user.preferredUsername ?? user.name
                        {
                            openURL(URL(string: "https://huggingface.co/\(username)")!)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if let user = authManager.currentUser {
                                if let pictureURL = user.picture,
                                    let url = URL(string: pictureURL)
                                {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.secondary.opacity(0.2))
                                            .overlay {
                                                Image(systemName: "person.fill")
                                                    .foregroundStyle(.secondary)
                                                    .font(.caption)
                                            }
                                            .redacted(reason: .placeholder)
                                    }
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    if let name = user.name {
                                        Text(name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                    }

                                    if let username = user.preferredUsername {
                                        Text("@\(username)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .fixedSize()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help("View Profile on Hugging Face")

                    Spacer()

                    Button {
                        showSignOutConfirmation = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                    .help("Sign Out")
                    .confirmationDialog(
                        "Are you sure you want to sign out?",
                        isPresented: $showSignOutConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Sign Out", role: .destructive) {
                            Task {
                                await authManager.signOut()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            } else {
                // Unauthenticated state
                Button {
                    Task {
                        await authManager.signIn()
                    }
                } label: {
                    HStack {
                        Image("HuggingFace")
                            .renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        Text("Sign in with Hugging Face")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let error = authManager.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(12)
    }
}
