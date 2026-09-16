import CryptoKit
import Foundation

enum DeterministicID {
    private static let namespace = "com.hoaglun.forgotthemilk/seed/v1"

    static func category(_ name: String) -> UUID {
        uuid(from: "\(namespace)/category/\(name)")
    }

    static func catalogItem(category: String, label: String) -> UUID {
        uuid(from: "\(namespace)/catalog/\(category)/\(label)")
    }

    private static func uuid(from string: String) -> UUID {
        var bytes = sha256(Data(string.utf8))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func sha256(_ data: Data) -> [UInt8] {
        var hasher = SHA256()
        data.withUnsafeBytes { hasher.update(bufferPointer: $0) }
        let digest = hasher.finalize()
        var bytes = [UInt8](repeating: 0, count: SHA256Digest.byteCount)
        digest.withUnsafeBytes { bytes = Array($0) }
        return bytes
    }
}
