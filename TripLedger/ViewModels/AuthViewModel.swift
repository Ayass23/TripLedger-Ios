import Foundation
import Combine
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var currentUser: UserModel?
    @Published var isAuthenticated = false
    @Published var isCheckingSession = true
    @Published var isLoading       = false
    @Published var errorMessage:   String?

    private let authService = AuthService.shared
    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        listenToAuthState()
    }

    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Auth State Listener
    private func listenToAuthState() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                if let uid = user?.uid {
                    do {
                        self.currentUser    = try await AuthService.shared.fetchUser(uid: uid)
                        self.isAuthenticated = true
                    } catch {
                        self.errorMessage   = error.localizedDescription
                        self.isAuthenticated = false
                    }
                } else {
                    self.currentUser     = nil
                    self.isAuthenticated = false
                }
                self.isCheckingSession = false
            }
        }
    }

    // MARK: - Register
    func register(name: String, email: String, password: String) async {
        isLoading     = true
        errorMessage  = nil
        defer { isLoading = false }
        do {
            let user = try await authService.signUp(name: name, email: email, password: password)
            currentUser     = user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Login
    func login(email: String, password: String) async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user = try await authService.signIn(email: email, password: password)
            currentUser     = user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reset Password
    enum ResetPasswordResult: Equatable {
        case success
        case emailNotFound
        case failure(String)
    }

    func resetPassword(email: String) async -> ResetPasswordResult {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await authService.resetPassword(email: email)
            return .success
        } catch AppError.emailNotFound {
            return .emailNotFound
        } catch {
            errorMessage = error.localizedDescription
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Change Password
    func changePassword(currentPassword: String, newPassword: String) async -> Bool {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }

        // Validate new password length
        guard newPassword.count >= 8 else {
            errorMessage = AppError.weakPassword.errorDescription
            return false
        }

        do {
            try await authService.changePassword(currentPassword: currentPassword, newPassword: newPassword)
            return true
        } catch let error as NSError {
            // Handle Firebase auth errors
            if error.code == AuthErrorCode.wrongPassword.rawValue {
                errorMessage = AppError.wrongPassword.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }

    // MARK: - Logout
    func logout() {
        try? authService.signOut()
        currentUser     = nil
        isAuthenticated = false
    }

    // MARK: - Refresh user
    func refreshUser() async {
        guard let uid = authService.currentUID else { return }
        currentUser = try? await authService.fetchUser(uid: uid)
    }
}
