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
    @Published var showSuspendedAlert = false
    @Published var suspendReason: String?
    @Published var suspendedUserInfo: (uid: String, name: String, email: String)?

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
                    // If we already have the currentUser from login/register flow, skip fetch
                    if self.currentUser != nil && self.currentUser?.uid == uid {
                        self.isAuthenticated = true
                        self.isCheckingSession = false
                        return
                    }

                    // Retry mechanism for fetching user (handles race condition after register)
                    var retryCount = 0
                    let maxRetries = 3
                    var fetchedUser: UserModel? = nil

                    while retryCount < maxRetries && fetchedUser == nil {
                        do {
                            fetchedUser = try await AuthService.shared.fetchUser(uid: uid)
                        } catch {
                            retryCount += 1
                            if retryCount < maxRetries {
                                // Wait a bit before retrying (document might not be ready)
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            }
                        }
                    }

                    if let user = fetchedUser {
                        self.currentUser = user
                        self.isAuthenticated = true
                        self.errorMessage = nil
                    } else {
                        // Only show error if we haven't set currentUser from login/register
                        if self.currentUser == nil {
                            self.errorMessage = "Gagal memuat data pengguna. Silakan coba lagi."
                            self.isAuthenticated = false
                        }
                    }
                } else {
                    self.currentUser     = nil
                    self.isAuthenticated = false
                    // Only clear error if not showing suspend alert (preserve suspend state)
                    if !self.showSuspendedAlert {
                        self.errorMessage = nil
                    }
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
            // Check if account is suspended (rare but possible if re-registering)
            if let appError = error as? AppError, case .accountSuspended = appError {
                showSuspendedAlert = true
                return
            }

            let mappedError = authService.mapFirebaseError(error)
            errorMessage = mappedError.localizedDescription
        }
    }

    // MARK: - Login
    func login(email: String, password: String) async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user = try await authService.signIn(email: email, password: password)

            // Check if user is suspended
            if user.isSuspended {
                print("⚠️ [AuthVM] User is suspended during login")

                // Set suspend info FIRST before logout
                suspendReason = user.suspendReason ?? "Akun Anda telah disuspend oleh admin."
                suspendedUserInfo = (uid: user.uid, name: user.displayName, email: user.email)
                showSuspendedAlert = true

                print("📝 [AuthVM] Suspend reason set: \(suspendReason ?? "nil")")

                // Logout after setting suspend info
                try? authService.signOut()

                return
            }

            currentUser     = user
            isAuthenticated = true
        } catch {
            // Check if account is suspended
            if let appError = error as? AppError, case .accountSuspended = appError {
                showSuspendedAlert = true
                return
            }

            let mappedError = authService.mapFirebaseError(error)
            errorMessage = mappedError.localizedDescription
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

    // MARK: - Clear errors
    func clearErrors() {
        errorMessage = nil
        // Don't reset showSuspendedAlert here - it's managed separately
    }
}
