//
//  SocialLoginView.swift
//  zenloop
//
//  Vue de login pour les features sociales
//  Sign in with Apple uniquement
//

import SwiftUI
import AuthenticationServices

struct SocialLoginView: View {
    @ObservedObject private var authManager = AuthenticationManager.shared
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Background optimisé
            OptimizedBackground(currentState: .idle)
                .ignoresSafeArea(.all, edges: .all)

            VStack(spacing: 40) {
                Spacer()

                // Logo & Title
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.3),
                                        Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: "person.2.circle.fill")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 8) {
                        Text(String(localized: "social_login_title"))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        Text(String(localized: "social_login_subtitle"))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -30)

                // Features
                VStack(spacing: 16) {
                    FeatureRow(
                        icon: "person.3.fill",
                        title: String(localized: "social_login_feature1_title"),
                        description: String(localized: "social_login_feature1_desc")
                    )

                    FeatureRow(
                        icon: "message.fill",
                        title: String(localized: "social_login_feature2_title"),
                        description: String(localized: "social_login_feature2_desc")
                    )

                    FeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: String(localized: "social_login_feature3_title"),
                        description: String(localized: "social_login_feature3_desc")
                    )
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                Spacer()

                // ✅ FIX: Utiliser directement SignInWithAppleButton natif
                // Plus de wrapper Button custom qui causait des conflits
                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = authManager.prepareAppleNonce()
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            print("🍎 [SocialLogin] Apple sign in succeeded")
                            authManager.handleAppleAuthorization(authorization)
                        case .failure(let error):
                            print("❌ [SocialLogin] Apple sign in failed: \(error.localizedDescription)")
                            authManager.authenticationError = error
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)

                    Text(String(localized: "social_login_cta_hint"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            print("🔍 [SocialLoginView] View appeared")
            print("🔍 [SocialLoginView] isAuthenticated: \(authManager.isAuthenticated)")
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
                showContent = true
            }
        }
        .alert(String(localized: "social_login_error_title"), isPresented: .constant(authManager.authenticationError != nil)) {
            Button(String(localized: "social_login_error_ok")) {
                authManager.authenticationError = nil
            }
        } message: {
            if let error = authManager.authenticationError {
                Text(error.localizedDescription)
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    SocialLoginView()
}