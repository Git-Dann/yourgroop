import SwiftUI

struct SignInView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemTeal).opacity(0.14),
                    Color(uiColor: .systemIndigo).opacity(0.10),
                    Color(uiColor: .systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 74, height: 74)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(spacing: 8) {
                    Text("Welcome to YourGroop")
                        .font(.title2.weight(.bold))

                    Text("Find and manage your local communities across the North West.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        isSigningIn = true
                        await appModel.signIn()
                        isSigningIn = false
                    }
                } label: {
                    Group {
                        if isSigningIn {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label("Sign In", systemImage: "person.badge.key")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSigningIn)
                .accessibilityLabel("Sign in")
                .accessibilityHint("Starts mocked sign in and loads your groops")

                Text("Mocked authentication for starter app")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }
}
