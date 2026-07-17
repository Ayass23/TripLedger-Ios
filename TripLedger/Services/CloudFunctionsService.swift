import Foundation
import FirebaseAuth

// MARK: - Cloud Function Error
enum CloudFunctionError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Sesi kamu sudah berakhir. Silakan login ulang."
        case .invalidResponse:  return "Respons server tidak valid."
        case .server(let message): return message
        }
    }
}

// MARK: - Cloud Functions Service
/// Calls Firebase callable functions.
///
/// The app doesn't link the FirebaseFunctions SDK, so this speaks the callable
/// protocol directly over HTTPS: POST `{"data": ...}` with the caller's ID
/// token, and read back either `result` or `error`.
final class CloudFunctionsService {

    static let shared = CloudFunctionsService()
    private init() {}

    private let region    = "asia-southeast2"
    private let projectID = "trip-ledger-d91ba"

    @discardableResult
    func call(_ name: String, data: [String: Any] = [:]) async throws -> [String: Any] {
        guard let currentUser = Auth.auth().currentUser else {
            throw CloudFunctionError.notAuthenticated
        }

        // Proves to the function who is calling, so it can enforce admin-only access.
        let idToken = try await currentUser.getIDToken()

        guard let url = URL(string: "https://\(region)-\(projectID).cloudfunctions.net/\(name)") else {
            throw CloudFunctionError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": data])
        // A cascading delete touches many documents; give it room to finish.
        request.timeoutInterval = 120

        let (body, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw CloudFunctionError.invalidResponse
        }

        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]

        guard (200...299).contains(http.statusCode) else {
            let message = (json?["error"] as? [String: Any])?["message"] as? String
            AppLog.debug("❌ [CloudFn] \(name) failed (HTTP \(http.statusCode)): \(message ?? "unknown")")
            throw CloudFunctionError.server(message ?? "Gagal memanggil \(name). (HTTP \(http.statusCode))")
        }

        AppLog.debug("✅ [CloudFn] \(name) succeeded")
        return (json?["result"] as? [String: Any]) ?? [:]
    }
}
