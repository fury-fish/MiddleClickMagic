import Foundation

enum AppPreferences {
    private static let wideAreaKey = "wideAreaMiddleClickEnabled"
    private static let centerXKey = "middleClickCenterX"

    static var wideAreaMiddleClickEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: wideAreaKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: wideAreaKey)
        }
    }

    static var middleClickCenterX: Double? {
        get {
            guard UserDefaults.standard.object(forKey: centerXKey) != nil else {
                return nil
            }

            return UserDefaults.standard.double(forKey: centerXKey)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: centerXKey)
            } else {
                UserDefaults.standard.removeObject(forKey: centerXKey)
            }
        }
    }
}
