import Foundation
import FirebaseAuth
import AuthenticationServices
import Combine
import SwiftUI
import CryptoKit

/// AuthManager: singleton wrapper around FirebaseAuth for use in SwiftUI.
/// - Provides: register/login/signOut, Apple sign-in helper (basic). For production,
///   ensure you use a proper nonce flow for Sign in with Apple (see generateRandomNonce()).
public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()
    @Published public private(set) var firebaseUser: FirebaseAuth.User? = nil
    private var handle: AuthStateDidChangeListenerHandle?

    // If you implement the full nonce flow, store the current nonce here between request and callback.
    public var currentNonce: String? = nil

    private init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.firebaseUser = user
                if let u = user { print("DBG: Auth state changed. uid=\(u.uid)") }
                else { print("DBG: signed out") }
            }
        }
    }

    // MARK: Email / Password
    // AuthManager.register をこれに置き換えてください（デバッグ用）
    public func register(email: String, password: String, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        // クライアント側バリデーション（省略可能）
        guard password.count >= 6 else {
            let err = NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Password must be at least 6 characters"])
            completion(.failure(err))
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                let ns = error as NSError
                print("DBG: createUser error -> localizedDescription: \(ns.localizedDescription)")
                print("DBG: NSError domain=\(ns.domain) code=\(ns.code)")
                print("DBG: userInfo = \(ns.userInfo)")
                if let underlying = ns.userInfo[NSUnderlyingErrorKey] {
                    print("DBG: underlyingError = \(underlying)")
                }
                if let authCode = AuthErrorCode(rawValue: ns.code) {
                    print("DBG: AuthErrorCode = \(authCode) (\(authCode.rawValue))")
                }
                completion(.failure(error))
                return
            }

            if let user = authResult?.user {
                print("DBG: createUser success uid=\(user.uid) email=\(user.email ?? "<no-email>")")
                completion(.success(user))
            } else {
                let err2 = NSError(domain: "AuthManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "createUser returned no user and no error"])
                print("DBG: unexpected:", err2)
                completion(.failure(err2))
            }
        }
    }

    public func login(email: String, password: String, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { res, err in
            if let err = err { completion(.failure(err)); return }
            if let user = res?.user { completion(.success(user)) }
        }
    }

    public func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: Google sign-in (skeleton)
    // Integrate GoogleSignIn SDK as described by Firebase docs when you are ready.
    public func signInWithGoogle(presenting windowScene: UIWindowScene?, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        // Placeholder: follow Firebase's Google sign-in guide to implement.
        completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google sign-in not implemented. Integrate GoogleSignIn SDK per Firebase docs."])))
    }

    // MARK: Sign in with Apple (callback handler)
    /// Call this after you receive an ASAuthorizationAppleIDCredential from the Apple flow.
    /// For now this passes an empty rawNonce to avoid the compile error. For production,
    /// implement the nonce flow:
    /// 1) before starting the authorization request, generate `nonce = generateRandomNonce()` and
    ///    set `currentNonce = nonce`.
    /// 2) set `request.nonce = sha256(nonce)` on the ASAuthorizationAppleIDRequest.
    /// 3) when handling the callback, pass the original `nonce` (not SHA256) as rawNonce here.
  /*  public func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String? = nil, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        guard let tokenData = credential.identityToken,
              let idTokenString = String(data: tokenData, encoding: .utf8) else {
            completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identityToken"])))
            return
        }

        let rawNonceToUse = rawNonce ?? ""

        // 明示的に FirebaseAuth 名前空間を付けて呼ぶ（これで "unavailable in Swift" エラーが回避される）
        let firebaseCredential = FirebaseAuth.OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: rawNonceToUse)

        Auth.auth().signIn(with: firebaseCredential) { res, err in
            if let err = err { completion(.failure(err)); return }
            if let user = res?.user { completion(.success(user)) }
        }
    } */

    // MARK: Nonce helpers (useful for proper Sign in with Apple implementation)
    /// Generates a random nonce string of the specified length.
    public func generateRandomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms: [UInt8] = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with status: \(status)")
            }

            for rnd in randoms {
                if remainingLength == 0 { break }
                let idx = Int(rnd) % charset.count
                result.append(charset[idx])
                remainingLength -= 1
            }
        }
        return result
    }

    /// Return the SHA256 hash string for the input.
    public func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
