//
//  AuthenticationManager.swift
//  zenloop
//
//  Gère l'authentification Firebase avec Sign in with Apple
//  Intégré avec SessionManager pour les features sociales
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
import os.log

private let authLogger = Logger(subsystem: "com.app.zenloop", category: "Authentication")

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()

    // MARK: - Published Properties

    @Published var isAuthenticated = false
    @Published var currentFirebaseUser: User?
    @Published var authenticationError: Error?

    // ✅ FIX: Track Firebase readiness instead of using arbitrary sleep
    @Published var isReady = false

    // MARK: - Private Properties

    private var currentNonce: String?
    private var authStateListener: AuthStateDidChangeListenerHandle?

    private override init() {
        super.init()
        authLogger.info("🔥 AuthenticationManager initializing (waiting for Firebase)...")
        // ✅ FIX: Don't do anything here — wait for Firebase to be configured
        // Call configure() from zenloopApp after FirebaseApp.configure()
    }

    // ✅ NEW: Call this AFTER FirebaseApp.configure() has completed
    func configure() {
        guard !isReady else {
            authLogger.warning("⚠️ AuthenticationManager already configured")
            return
        }

        authLogger.info("🔍 Configuring AuthenticationManager (Firebase is ready)...")

        // Check if already authenticated
        if let user = Auth.auth().currentUser {
            self.currentFirebaseUser = user
            self.isAuthenticated = true
            authLogger.info("✅ User already authenticated: \(user.uid)")

            // ✅ FIX: Load user data and sessions
            Task { @MainActor in
                await self.setupSessionUser(user: user)
            }
        } else {
            self.isAuthenticated = false
            authLogger.info("🔓 No user authenticated")
        }

        // Listen for auth state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }

                let previousAuth = self.isAuthenticated
                self.currentFirebaseUser = user
                self.isAuthenticated = user != nil

                authLogger.info("🔐 Auth state changed: user=\(user?.uid ?? "nil"), isAuth=\(self.isAuthenticated)")

                if let user = user {
                    await self.setupSessionUser(user: user)
                } else if previousAuth {
                    // User signed out — clean up
                    authLogger.info("🔓 User signed out — stopping listeners")
                    SessionManager.shared.stopListeners()
                    SessionManager.shared.clearLocalState()
                }
            }
        }

        isReady = true
        authLogger.info("✅ AuthenticationManager configured and ready")
    }

    // MARK: - Sign in with Apple

    func signInWithApple() {
        authLogger.info("🍎 Starting Sign in with Apple")

        let nonce = randomNonceString()
        currentNonce = nonce

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.performRequests()
    }

    // ✅ NEW: Handle Apple authorization from native SignInWithAppleButton
    func handleAppleAuthorization(_ authorization: ASAuthorization) {
        authorizationController(
            controller: ASAuthorizationController(authorizationRequests: []),
            didCompleteWithAuthorization: authorization
        )
    }

    // MARK: - Sign Out

    func signOut() throws {
        authLogger.info("🚪 Signing out")

        do {
            try Auth.auth().signOut()

            // Stop SessionManager listeners and clear state
            SessionManager.shared.stopListeners()
            SessionManager.shared.clearLocalState()

            isAuthenticated = false
            currentFirebaseUser = nil

            authLogger.info("✅ Signed out successfully")
        } catch {
            authLogger.error("❌ Sign out error: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Session User Setup

    private func setupSessionUser(user: User) async {
        authLogger.info("👤 Setting up SessionUser for: \(user.uid)")

        // Get username from display name or use default
        let username = user.displayName ?? "User\(String(user.uid.prefix(6)))"
        let appleUserId = user.providerData.first?.uid ?? user.uid

        do {
            try await SessionManager.shared.setupUser(
                uid: user.uid,
                username: username,
                appleUserId: appleUserId
            )

            // ✅ FIX: After user setup, load their sessions
            await SessionManager.shared.loadUserSessions()

            authLogger.info("✅ SessionUser setup complete + sessions loaded")
        } catch {
            authLogger.error("❌ SessionUser setup failed: \(error.localizedDescription)")
            authenticationError = error
        }
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        authLogger.info("🍎 Apple authorization completed")

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            authLogger.error("❌ Invalid credential type")
            return
        }

        guard let nonce = currentNonce else {
            authLogger.error("❌ Invalid state: nonce is nil")
            return
        }

        guard let appleIDToken = appleIDCredential.identityToken else {
            authLogger.error("❌ Unable to fetch identity token")
            return
        }

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            authLogger.error("❌ Unable to serialize token string from data")
            return
        }

        // Create Firebase credential
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        // Sign in to Firebase
        Task {
            do {
                let result = try await Auth.auth().signIn(with: credential)
                let user = result.user

                authLogger.critical("✅ Firebase sign in successful: \(user.uid)")

                // ✅ FIX: The auth state listener will handle the rest
                // No need to manually set isAuthenticated here — the listener does it

            } catch {
                authLogger.error("❌ Firebase sign in error: \(error.localizedDescription)")
                await MainActor.run {
                    self.authenticationError = error
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        authLogger.error("❌ Apple authorization error: \(error.localizedDescription)")

        Task { @MainActor in
            self.authenticationError = error
        }
    }
}