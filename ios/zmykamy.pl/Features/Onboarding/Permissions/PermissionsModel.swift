import AVFoundation
import Observation
import UserNotifications

enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}

@Observable
final class PermissionsModel {
    private(set) var camera: PermissionStatus = .notDetermined
    private(set) var notifications: PermissionStatus = .notDetermined

    func refresh() async {
        camera = switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifications = switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func requestCamera() async {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        await refresh()
    }

    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        await refresh()
    }
}
