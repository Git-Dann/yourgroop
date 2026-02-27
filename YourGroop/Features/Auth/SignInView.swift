import SwiftUI
import UIKit

struct SignInView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isSigningIn = false
    @State private var showSignUpMessage = false

    var body: some View {
        ZStack(alignment: .bottom) {
            heroImage
                .ignoresSafeArea()

            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.3), .black.opacity(0.54)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("Welcome to YourGroop")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Find and manage your local communities across the UK.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button {
                        showSignUpMessage = true
                    } label: {
                        Label("Sign Up", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .accessibilityHint("Opens sign up guidance")

                    Button {
                        Task {
                            isSigningIn = true
                            await appModel.signIn()
                            isSigningIn = false
                        }
                    } label: {
                        ZStack {
                            Text("Demo")
                                .opacity(isSigningIn ? 0 : 1)
                            ProgressView()
                                .opacity(isSigningIn ? 1 : 0)
                        }
                        .frame(height: 22)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(.white)
                    .disabled(isSigningIn)
                    .accessibilityHint("Enters the demo app")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .alert("Sign up is coming next", isPresented: $showSignUpMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Use Demo to explore the full app flow now.")
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if UIImage(named: "LockHeroPhoto") != nil {
            Image("LockHeroPhoto")
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemGray5),
                    Color(uiColor: .systemGray4),
                    Color(uiColor: .systemGray3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(
                Image(systemName: "photo.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            )
        }
    }
}
