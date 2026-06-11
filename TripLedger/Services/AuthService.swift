import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Auth Service
final class AuthService {

    static let shared = AuthService()
    private let auth  = Auth.auth()
    private let db    = Firestore.firestore()

    private init() {}

    // MARK: - Current User
    var currentUID: String? { auth.currentUser?.uid }
    var isSignedIn: Bool    { auth.currentUser != nil }

    // MARK: - Sign Up
    func signUp(name: String, email: String, password: String) async throws -> UserModel {
        let result = try await auth.createUser(withEmail: email, password: password)
        let uid    = result.user.uid

        // Update display name
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()

        // Create Firestore document
        let user = UserModel(
            uid:            uid,
            displayName:    name,
            email:          email,
            avatarURL:      nil,
            avatarPublicID: nil,
            bankInfo:       nil,
            role:           .user,
            isSuspended:    false,
            fcmToken:       nil,
            createdAt:      Timestamp(date: Date()),
            friendUIDs:     []
        )
        try db.collection("users").document(uid).setData(from: user)
        return user
    }

    // MARK: - Sign In
    func signIn(email: String, password: String) async throws -> UserModel {
        let result = try await auth.signIn(withEmail: email, password: password)
        let uid    = result.user.uid
        return try await fetchUser(uid: uid)
    }

    // MARK: - Fetch user doc
    func fetchUser(uid: String) async throws -> UserModel {
        let snap = try await db.collection("users").document(uid).getDocument()
        guard let user = try? snap.data(as: UserModel.self) else {
            throw AppError.userNotFound
        }
        if user.isSuspended { throw AppError.accountSuspended }
        return user
    }

    // MARK: - Reset Password
    func resetPassword(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch let error as NSError {
            // Firebase Auth throws userNotFound when email is not registered
            if error.code == AuthErrorCode.userNotFound.rawValue {
                throw AppError.emailNotFound
            }
            throw error
        }
    }

    // MARK: - Change Password
    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let user = auth.currentUser, let email = user.email else {
            throw AppError.userNotFound
        }

        // Re-authenticate user with current password
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        try await user.reauthenticate(with: credential)

        // Update to new password
        try await user.updatePassword(to: newPassword)

        // Optional: Send email confirmation
        // try await user.sendEmailVerification()
    }

    // MARK: - Sign Out
    func signOut() throws {
        try auth.signOut()
    }

    // MARK: - Update FCM Token
    func updateFCMToken(_ token: String, uid: String) async throws {
        try await db.collection("users").document(uid).updateData(["fcmToken": token])
    }
}

// MARK: - App Errors
enum AppError: LocalizedError {
    case userNotFound
    case emailNotFound
    case accountSuspended
    case permissionDenied
    case wrongPassword
    case weakPassword
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .userNotFound:      return "Akun tidak ditemukan."
        case .emailNotFound:     return "Email ini belum terdaftar di TripLedger."
        case .accountSuspended:  return "Akun kamu telah disuspend. Hubungi admin."
        case .permissionDenied:  return "Kamu tidak memiliki izin untuk melakukan ini."
        case .wrongPassword:     return "Password lama salah."
        case .weakPassword:      return "Password baru harus minimal 8 karakter."
        case .unknown(let msg):  return msg
        }
    }
}
