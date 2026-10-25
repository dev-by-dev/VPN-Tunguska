import CryptoKit
import Foundation

public enum ProfileBackupError: LocalizedError, Equatable {
    case passphraseTooShort
    case malformedEnvelope
    case unsupportedVersion(Int)
    case unsupportedKDF(String)
    case invalidIterations
    case authenticationFailed
    case invalidProfilePayload(String)

    public var errorDescription: String? {
        switch self {
        case .passphraseTooShort:
            return "The backup passphrase must contain at least 12 characters."
        case .malformedEnvelope:
            return "The encrypted backup envelope is malformed."
        case .unsupportedVersion(let version):
            return "This backup format version is not supported: \(version)."
        case .unsupportedKDF(let kdf):
            return "This backup key-derivation function is not supported: \(kdf)."
        case .invalidIterations:
            return "The backup contains an unsafe key-derivation iteration count."
        case .authenticationFailed:
            return "The backup could not be decrypted. Check the passphrase and file integrity."
        case .invalidProfilePayload(let message):
            return "The backup contains an invalid profile: \(message)"
        }
    }
}

public struct ProfileBackupPayload: Equatable, Sendable {
    public let createdAt: Date
    public let activeProfileID: String?
    public let profiles: [ProfileIr]

    public init(createdAt: Date, activeProfileID: String?, profiles: [ProfileIr]) {
        self.createdAt = createdAt
        self.activeProfileID = activeProfileID
        self.profiles = profiles
    }
}

public enum ProfileBackup {
    public static let format = "tunguska.profile-backup"
    public static let version = 1
    public static let kdf = "PBKDF2-HMAC-SHA256"
    public static let defaultIterations = 210_000
    public static let minimumPassphraseLength = 12
    private static let keyLength = 32
    private static let saltLength = 16
    private static let additionalAuthenticatedData = Data("tunguska.profile-backup.v1".utf8)

    private struct Envelope: Codable {
        let format: String
        let version: Int
        let kdf: String
        let iterations: Int
        let salt: Data
        let sealedBox: Data
    }

    private struct Payload: Codable {
        let createdAt: Date
        let activeProfileID: String?
        let profiles: [ProfileIr]
    }

    public static func export(
        profiles: [ProfileIr],
        activeProfileID: String?,
        passphrase: String,
        createdAt: Date = Date()
    ) throws -> Data {
        guard passphrase.count >= minimumPassphraseLength else {
            throw ProfileBackupError.passphraseTooShort
        }
        try validate(profiles: profiles, activeProfileID: activeProfileID)

        let payload = Payload(
            createdAt: createdAt,
            activeProfileID: activeProfileID,
            profiles: profiles
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let plaintext = try encoder.encode(payload)

        let salt = randomBytes(count: saltLength)
        let key = try deriveKey(
            passphrase: passphrase,
            salt: salt,
            iterations: defaultIterations
        )
        let sealed = try AES.GCM.seal(
            plaintext,
            using: key,
            authenticating: additionalAuthenticatedData
        )
        guard let combined = sealed.combined else {
            throw ProfileBackupError.malformedEnvelope
        }

        let envelope = Envelope(
            format: format,
            version: version,
            kdf: kdf,
            iterations: defaultIterations,
            salt: salt,
            sealedBox: combined
        )
        let envelopeEncoder = JSONEncoder()
        envelopeEncoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try envelopeEncoder.encode(envelope)
    }

    public static func `import`(data: Data, passphrase: String) throws -> ProfileBackupPayload {
        guard passphrase.count >= minimumPassphraseLength else {
            throw ProfileBackupError.passphraseTooShort
        }

        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw ProfileBackupError.malformedEnvelope
        }
        guard envelope.format == format else {
            throw ProfileBackupError.malformedEnvelope
        }
        guard envelope.version == version else {
            throw ProfileBackupError.unsupportedVersion(envelope.version)
        }
        guard envelope.kdf == kdf else {
            throw ProfileBackupError.unsupportedKDF(envelope.kdf)
        }
        guard (10_000...1_000_000).contains(envelope.iterations) else {
            throw ProfileBackupError.invalidIterations
        }
        guard envelope.salt.count == saltLength, envelope.sealedBox.count > 28 else {
            throw ProfileBackupError.malformedEnvelope
        }

        let key = try deriveKey(
            passphrase: passphrase,
            salt: envelope.salt,
            iterations: envelope.iterations
        )
        let plaintext: Data
        do {
            let box = try AES.GCM.SealedBox(combined: envelope.sealedBox)
            plaintext = try AES.GCM.open(
                box,
                using: key,
                authenticating: additionalAuthenticatedData
            )
        } catch {
            throw ProfileBackupError.authenticationFailed
        }

        let payload: Payload
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            payload = try decoder.decode(Payload.self, from: plaintext)
        } catch {
            throw ProfileBackupError.malformedEnvelope
        }
        do {
            try validate(profiles: payload.profiles, activeProfileID: payload.activeProfileID)
        } catch let error as ProfileBackupError {
            throw error
        } catch {
            throw ProfileBackupError.invalidProfilePayload(error.localizedDescription)
        }
        return ProfileBackupPayload(
            createdAt: payload.createdAt,
            activeProfileID: payload.activeProfileID,
            profiles: payload.profiles
        )
    }

    private static func validate(profiles: [ProfileIr], activeProfileID: String?) throws {
        var ids = Set<String>()
        for profile in profiles {
            guard ids.insert(profile.id).inserted else {
                throw ProfileBackupError.invalidProfilePayload("duplicate profile identifier")
            }
            if let issue = profile.validationIssues().first {
                throw ProfileBackupError.invalidProfilePayload("\(issue.field): \(issue.message)")
            }
        }
        if let activeProfileID, !ids.contains(activeProfileID) {
            throw ProfileBackupError.invalidProfilePayload("The active profile is not present in the backup.")
        }
    }

    private static func randomBytes(count: Int) -> Data {
        var generator = SystemRandomNumberGenerator()
        var bytes = [UInt8]()
        bytes.reserveCapacity(count)
        for _ in 0..<count {
            bytes.append(UInt8.random(in: UInt8.min...UInt8.max, using: &generator))
        }
        return Data(bytes)
    }

    private static func deriveKey(
        passphrase: String,
        salt: Data,
        iterations: Int
    ) throws -> SymmetricKey {
        guard let password = passphrase.data(using: .utf8), !password.isEmpty else {
            throw ProfileBackupError.passphraseTooShort
        }
        let derived = pbkdf2(
            password: password,
            salt: salt,
            iterations: iterations,
            keyLength: keyLength
        )
        return SymmetricKey(data: derived)
    }

    private static func pbkdf2(
        password: Data,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) -> Data {
        let hmacKey = SymmetricKey(data: password)
        var output = Data()
        var blockIndex: UInt32 = 1
        while output.count < keyLength {
            var block = salt
            block.append(contentsOf: withUnsafeBytes(of: blockIndex.bigEndian) { Array($0) })
            var u = Data(HMAC<SHA256>.authenticationCode(for: block, using: hmacKey))
            var accumulator = u
            if iterations > 1 {
                for _ in 1..<iterations {
                    u = Data(HMAC<SHA256>.authenticationCode(for: u, using: hmacKey))
                    for index in accumulator.indices {
                        accumulator[index] ^= u[index]
                    }
                }
            }
            output.append(accumulator)
            blockIndex += 1
        }
        return output.prefix(keyLength)
    }
}
