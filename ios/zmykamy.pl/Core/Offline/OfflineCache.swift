import Foundation

nonisolated enum OfflineCache {
    private static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "offline", directoryHint: .isDirectory)
    }

    private static var filesDirectory: URL {
        directory.appending(path: "files", directoryHint: .isDirectory)
    }

    static func save(_ value: some Encodable, as name: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(value)
            try data.write(to: directory.appending(path: "\(name).json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            return
        }
    }

    static func load<Value: Decodable>(_ type: Value.Type, name: String) -> Value? {
        guard let data = try? Data(contentsOf: directory.appending(path: "\(name).json")) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func fileURL(named name: String) -> URL {
        filesDirectory.appending(path: name)
    }

    static func storeFile(at location: URL, named name: String) throws -> URL {
        try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        let destination = fileURL(named: name)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: location, to: destination)
        return destination
    }

    static func removeFile(named name: String) {
        try? FileManager.default.removeItem(at: fileURL(named: name))
    }

    static func clear() {
        try? FileManager.default.removeItem(at: directory)
    }
}
