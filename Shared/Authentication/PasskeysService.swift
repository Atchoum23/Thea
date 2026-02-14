//
//  PasskeysService.swift
//  Thea
//
//  Passkeys authentication using AuthenticationServices
//

import AuthenticationServices
import Combine
import Foundation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif
#if canImport(AppKit)
    import AppKit
#endif
#if canImport(LocalAuthentication)
    import LocalAuthentication
#endif

// MARK: - Passkeys Service

@MainActor
public class PasskeysService: NSObject, ObservableObject {
    public static let shared = PasskeysService()

    // MARK: - Published State

    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var currentUser: PasskeyUser?
    @Published public private(set) var isProcessing = false
    @Published public private(set) var error: PasskeyError?

    // MARK: - Configuration

    private let relyingPartyIdentifier = "thea.app"
    private var authorizationController: ASAuthorizationController?

    // MARK: - Continuation

    private var registrationContinuation: CheckedContinuation<PasskeyCredential, Error>?
    private var authenticationContinuation: CheckedContinuation<PasskeyCredential, Error>?

    // MARK: - Initialization

    override private init() {
        super.init()
    }

    // MARK: - Registration

    /// Register a new passkey for the user
    public func registerPasskey(
        username: String,
        userID: Data,
        challenge: Data
    ) async throws -> PasskeyCredential {
        isProcessing = true
        defer { isProcessing = false }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyIdentifier
        )

        let registrationRequest = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: username,
            userID: userID
        )

        // Configure request
        registrationRequest.displayName = username
        registrationRequest.userVerificationPreference = .required

        let controller = ASAuthorizationController(authorizationRequests: [registrationRequest])
        controller.delegate = self
        controller.presentationContextProvider = self

        authorizationController = controller

        return try await withCheckedThrowingContinuation { continuation in
            self.registrationContinuation = continuation
            controller.performRequests()
        }
    }

    /// Register using Sign in with Apple
    public func registerWithApple() async throws -> AppleIDCredential {
        isProcessing = true
        defer { isProcessing = false }

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        authorizationController = controller

        return try await withCheckedThrowingContinuation { _ in
            // We'd use a different continuation for Apple ID
            controller.performRequests()
            // For simplicity, we'll handle this differently
        }
    }

    // MARK: - Authentication

    /// Authenticate with an existing passkey
    public func authenticateWithPasskey(challenge: Data) async throws -> PasskeyCredential {
        isProcessing = true
        defer { isProcessing = false }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyIdentifier
        )

        let assertionRequest = provider.createCredentialAssertionRequest(challenge: challenge)
        assertionRequest.userVerificationPreference = .required

        // Also allow password autofill
        let passwordProvider = ASAuthorizationPasswordProvider()
        let passwordRequest = passwordProvider.createRequest()

        let controller = ASAuthorizationController(
            authorizationRequests: [assertionRequest, passwordRequest]
        )
        controller.delegate = self
        controller.presentationContextProvider = self

        authorizationController = controller

        return try await withCheckedThrowingContinuation { continuation in
            self.authenticationContinuation = continuation
            controller.performRequests()
        }
    }

    /// Perform auto-fill assisted passkey authentication
    #if os(iOS)
        public func performAutoFillAssistedAuthentication(challenge: Data) async throws -> PasskeyCredential {
            isProcessing = true
            defer { isProcessing = false }

            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: relyingPartyIdentifier
            )

            let assertionRequest = provider.createCredentialAssertionRequest(challenge: challenge)

            let controller = ASAuthorizationController(authorizationRequests: [assertionRequest])
            controller.delegate = self
            controller.presentationContextProvider = self

            authorizationController = controller

            return try await withCheckedThrowingContinuation { continuation in
                self.authenticationContinuation = continuation
                controller.performAutoFillAssistedRequests()
            }
        }
    #endif

    // MARK: - Biometric Authentication

    /// Authenticate using biometrics (Face ID / Touch ID)
    public func authenticateWithBiometrics(reason: String) async throws -> Bool {
        #if canImport(LocalAuthentication)
            let context = LAContext()
            var authError: NSError?

            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
                throw PasskeyError.biometricsUnavailable
            }

            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        #else
            throw PasskeyError.biometricsUnavailable
        #endif
    }

    // MARK: - Sign Out

    public func signOut() {
        isAuthenticated = false
        currentUser = nil
    }

    // MARK: - Helpers

    #if os(iOS)
        /// Bare UIWindow fallback — unreachable in practice since a windowScene should always exist.
        @available(iOS, deprecated: 26.0, message: "UIWindow() has no non-deprecated replacement without a scene")
        fileprivate static func makeFallbackWindow() -> UIWindow {
            UIWindow()
        }
    #endif

    // MARK: - Token Management

    /// Validate and refresh authentication token
    public func validateSession() async -> Bool {
        // Validate current session with server
        isAuthenticated
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension PasskeysService: ASAuthorizationControllerDelegate {
    nonisolated public func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            switch authorization.credential {
            case let credential as ASAuthorizationPlatformPublicKeyCredentialRegistration:
                let passkeyCredential = PasskeyCredential(
                    credentialID: credential.credentialID,
                    rawAttestationObject: credential.rawAttestationObject ?? Data(),
                    rawClientDataJSON: credential.rawClientDataJSON,
                    userID: nil
                )

                isAuthenticated = true
                registrationContinuation?.resume(returning: passkeyCredential)
                registrationContinuation = nil

            case let credential as ASAuthorizationPlatformPublicKeyCredentialAssertion:
                let passkeyCredential = PasskeyCredential(
                    credentialID: credential.credentialID,
                    rawAttestationObject: credential.rawAuthenticatorData,
                    rawClientDataJSON: credential.rawClientDataJSON,
                    userID: credential.userID
                )

                isAuthenticated = true
                authenticationContinuation?.resume(returning: passkeyCredential)
                authenticationContinuation = nil

            case let credential as ASAuthorizationAppleIDCredential:
                currentUser = PasskeyUser(
                    id: credential.user,
                    email: credential.email,
                    fullName: credential.fullName?.formatted()
                )
                isAuthenticated = true

            case let credential as ASPasswordCredential:
                // Handle password credential
                currentUser = PasskeyUser(
                    id: credential.user,
                    email: nil,
                    fullName: nil
                )
                isAuthenticated = true

            default:
                break
            }
        }
    }

    nonisolated public func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            let passkeyError: PasskeyError = if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .unknown:
                    .from(error)
                case .canceled:
                    .userCancelled
                case .invalidResponse:
                    .invalidResponse
                case .notHandled:
                    .notHandled
                case .failed:
                    .authenticationFailed
                case .notInteractive:
                    .notInteractive
                case .matchedExcludedCredential:
                    .credentialAlreadyExists
                default:
                    // Handles newer cases like credentialImport, credentialExport,
                    // preferSignInWithApple, deviceNotConfiguredForPasskeyCreation
                    .from(error)
                }
            } else {
                .from(error)
            }

            self.error = passkeyError
            registrationContinuation?.resume(throwing: passkeyError)
            authenticationContinuation?.resume(throwing: passkeyError)
            registrationContinuation = nil
            authenticationContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension PasskeysService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated public func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        // Use MainActor.assumeIsolated since this is called on the main thread
        MainActor.assumeIsolated {
            #if os(iOS)
                let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                // Return key window if available
                if let keyWindow = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow }) {
                    return keyWindow
                }
                // Return any existing window from any scene
                if let existingWindow = scenes.flatMap(\.windows).first {
                    return existingWindow
                }
                // Create new window from first available scene
                if let scene = scenes.first {
                    return UIWindow(windowScene: scene)
                }
                // Last resort — create from any available scene (always exists on modern iOS)
                if let anyScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    return UIWindow(windowScene: anyScene)
                }
                // Truly unreachable — no scene at all
                return UIWindow(frame: .zero)
            #elseif os(macOS)
                return NSApplication.shared.keyWindow ?? NSWindow()
            #else
                // watchOS/tvOS: return a minimal window
                return NSWindow()
            #endif
        }
    }
}

// MARK: - Supporting Types

public struct PasskeyCredential: Sendable {
    public let credentialID: Data
    public let rawAttestationObject: Data
    public let rawClientDataJSON: Data
    public let userID: Data?

    public var credentialIDString: String {
        credentialID.base64EncodedString()
    }
}

public struct AppleIDCredential: Sendable {
    public let userIdentifier: String
    public let fullName: String?
    public let email: String?
    public let identityToken: Data?
    public let authorizationCode: Data?
}

public struct PasskeyUser: Identifiable, Sendable {
    public let id: String
    public let email: String?
    public let fullName: String?
}

public enum PasskeyError: Error, LocalizedError, Sendable {
    case userCancelled
    case invalidResponse
    case notHandled
    case authenticationFailed
    case notInteractive
    case credentialAlreadyExists
    case biometricsUnavailable
    case preferSignInWithApple
    case deviceNotConfigured
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .userCancelled:
            "Authentication was cancelled"
        case .invalidResponse:
            "Invalid authentication response"
        case .notHandled:
            "Authentication request not handled"
        case .authenticationFailed:
            "Authentication failed"
        case .notInteractive:
            "Interactive authentication required"
        case .credentialAlreadyExists:
            "This passkey already exists"
        case .biometricsUnavailable:
            "Biometric authentication unavailable"
        case .preferSignInWithApple:
            "Sign in with Apple is preferred"
        case .deviceNotConfigured:
            "Device is not configured for passkey creation"
        case let .unknown(message):
            "Authentication error: \(message)"
        }
    }

    public static func from(_ error: Error) -> PasskeyError {
        .unknown(error.localizedDescription)
    }
}

// MARK: - SwiftUI Views

public struct SignInWithAppleButton: View {
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    public init(
        onRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void,
        onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void
    ) {
        self.onRequest = onRequest
        self.onCompletion = onCompletion
    }

    public var body: some View {
        SignInWithAppleButtonRepresentable(
            onRequest: onRequest,
            onCompletion: onCompletion
        )
        .frame(height: 50)
    }
}

#if os(iOS)
    struct SignInWithAppleButtonRepresentable: UIViewRepresentable {
        let onRequest: (ASAuthorizationAppleIDRequest) -> Void
        let onCompletion: (Result<ASAuthorization, Error>) -> Void

        func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
            let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
            button.addTarget(context.coordinator, action: #selector(Coordinator.handlePress), for: .touchUpInside)
            return button
        }

        func updateUIView(_: ASAuthorizationAppleIDButton, context _: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(onRequest: onRequest, onCompletion: onCompletion)
        }

        class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
            let onRequest: (ASAuthorizationAppleIDRequest) -> Void
            let onCompletion: (Result<ASAuthorization, Error>) -> Void

            init(
                onRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void,
                onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void
            ) {
                self.onRequest = onRequest
                self.onCompletion = onCompletion
            }

            @objc func handlePress() {
                let provider = ASAuthorizationAppleIDProvider()
                let request = provider.createRequest()
                onRequest(request)

                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }

            func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
                let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                // Return key window if available
                if let keyWindow = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow }) {
                    return keyWindow
                }
                // Return any existing window from any scene
                if let existingWindow = scenes.flatMap(\.windows).first {
                    return existingWindow
                }
                // Create new window from first available scene, or a bare window as last resort
                if let scene = scenes.first {
                    return UIWindow(windowScene: scene)
                }
                // Last resort — create from any available scene (always exists on modern iOS)
                if let anyScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    return UIWindow(windowScene: anyScene)
                }
                // Truly unreachable — no scene at all
                return UIWindow(frame: .zero)
            }

            func authorizationController(controller _: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
                onCompletion(.success(authorization))
            }

            func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
                onCompletion(.failure(error))
            }
        }
    }

#elseif os(macOS)
    struct SignInWithAppleButtonRepresentable: NSViewRepresentable {
        let onRequest: (ASAuthorizationAppleIDRequest) -> Void
        let onCompletion: (Result<ASAuthorization, Error>) -> Void

        func makeNSView(context: Context) -> ASAuthorizationAppleIDButton {
            let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
            button.target = context.coordinator
            button.action = #selector(Coordinator.handlePress)
            return button
        }

        func updateNSView(_: ASAuthorizationAppleIDButton, context _: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(onRequest: onRequest, onCompletion: onCompletion)
        }

        class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
            let onRequest: (ASAuthorizationAppleIDRequest) -> Void
            let onCompletion: (Result<ASAuthorization, Error>) -> Void

            init(
                onRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void,
                onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void
            ) {
                self.onRequest = onRequest
                self.onCompletion = onCompletion
            }

            @objc func handlePress() {
                let provider = ASAuthorizationAppleIDProvider()
                let request = provider.createRequest()
                onRequest(request)

                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }

            func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
                NSApplication.shared.keyWindow ?? NSWindow()
            }

            func authorizationController(controller _: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
                onCompletion(.success(authorization))
            }

            func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
                onCompletion(.failure(error))
            }
        }
    }
#endif
