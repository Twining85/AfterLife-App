import Foundation
import LocalAuthentication

final class BiometricAuthService {
    static let shared = BiometricAuthService()

    private init() {}

    enum BiometricAuthError: Error, LocalizedError {
        case notAvailable
        case failed

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Face ID oder Touch ID ist auf diesem Gerät nicht verfügbar. Bitte melde dich mit E-Mail und Passwort an."
            case .failed:
                return "Die biometrische Anmeldung konnte nicht bestätigt werden. Bitte melde dich mit E-Mail und Passwort an."
            }
        }
    }

    func authenticate(reason: String) async throws {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricAuthError.notAvailable
        }

        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )

        guard success else {
            throw BiometricAuthError.failed
        }
    }
}
