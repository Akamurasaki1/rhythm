import SwiftUI
import FirebaseAuth

/// シンプルな Email / Password サインイン画面（Apple 認証は除去）
public struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @ObservedObject private var auth = AuthManager.shared
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text("Sign In").font(.title)
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if let err = errorMessage {
                Text(err).foregroundColor(.red).font(.caption)
            }

            HStack(spacing: 12) {
                Button(action: {
                    AuthManager.shared.login(email: email, password: password) { res in
                        DispatchQueue.main.async {
                            switch res {
                            case .success: errorMessage = nil
                            case .failure(let e): errorMessage = e.localizedDescription
                            }
                        }
                    }
                }) {
                    Text("Login").frame(maxWidth: .infinity)
                }
                .padding().background(Color.blue).foregroundColor(.white).cornerRadius(8)

                Button(action: {
                    AuthManager.shared.register(email: email, password: password) { res in
                        DispatchQueue.main.async {
                            switch res {
                            case .success: errorMessage = nil
                            case .failure(let e): errorMessage = e.localizedDescription
                            }
                        }
                    }
                }) {
                    Text("Register").frame(maxWidth: .infinity)
                }
                .padding().background(Color.green).foregroundColor(.white).cornerRadius(8)
            }

            // 参考：Google サインイン用のボタン（未実装）
            // Button("Sign in with Google") { /* call AuthManager.signInWithGoogle */ }
            Spacer()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .padding()
    }
}
