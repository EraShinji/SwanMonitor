import Foundation
import LocalAuthentication
import Observation

@Observable
final class AppLock {
    var hasPIN = KeychainService.read(.appPIN) != nil
    var isLocked = KeychainService.read(.appPIN) != nil
    var biometrics = UserDefaults.standard.bool(forKey: "lock.biometrics") {
        didSet { UserDefaults.standard.set(biometrics, forKey: "lock.biometrics") }
    }
    var interval = UserDefaults.standard.object(forKey: "lock.interval") as? Double ?? 0 {
        didSet { UserDefaults.standard.set(interval, forKey: "lock.interval") }
    }
    private var backgroundAt: Date?

    func enteredBackground() { backgroundAt = Date() }
    func becameActive() {
        if hasPIN, let backgroundAt, Date().timeIntervalSince(backgroundAt) >= interval {
            isLocked = true
        }
        backgroundAt = nil
    }

    func verify(_ pin: String) -> Bool {
        let defaults = UserDefaults.standard
        guard Date().timeIntervalSince1970 >= defaults.double(forKey: "lock.retryAfter") else { return false }
        guard pin == KeychainService.read(.appPIN) else {
            let attempts = defaults.integer(forKey: "lock.attempts") + 1
            defaults.set(attempts, forKey: "lock.attempts")
            if attempts >= 5 {
                defaults.set(Date().addingTimeInterval(60).timeIntervalSince1970, forKey: "lock.retryAfter")
                defaults.set(0, forKey: "lock.attempts")
            }
            return false
        }
        defaults.set(0, forKey: "lock.attempts")
        return true
    }

    func savePIN(_ pin: String) -> Bool {
        guard pin.count == 6, pin.allSatisfy({ "0123456789".contains($0) }),
              KeychainService.save(pin, for: .appPIN) else { return false }
        hasPIN = true
        return true
    }

    func authenticateBiometrics() async -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                 localizedReason: String(localized: "验证身份以访问 SwanMonitor"))) == true
    }

    @discardableResult
    func clear() -> Bool {
        guard KeychainService.delete(.appPIN) else { return false }
        hasPIN = false
        isLocked = false
        biometrics = false
        interval = 0
        UserDefaults.standard.removeObject(forKey: "lock.attempts")
        UserDefaults.standard.removeObject(forKey: "lock.retryAfter")
        backgroundAt = nil
        return true
    }
}
