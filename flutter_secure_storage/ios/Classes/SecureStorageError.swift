
enum SecureStorageError: Error, LocalizedError {

    case unknown
    case alreadyExists
    case couldNotFound
    case incorrectPassphrase
    case parseFailed
    case unknownOSStatus(String, String)
    case unknownAccessControl(String)
    case other

    static func fromOSStatus( key: String?, oSStatus: OSStatus ) -> SecureStorageError? {

        let status = OSStatusType(rawValue: oSStatus)

        guard let statusType = status else { return .unknownOSStatus(key ?? "N/A", oSStatus.description) }

        switch statusType {
        case .noError:
            return nil
        case .functionwerenotvalid:
            return .other
        case .incorrectPassphrase:
            return .incorrectPassphrase
        case .alreadyExists:
            return .alreadyExists
        case .couldNotFound:
            return .couldNotFound
        case .attributedoesnotexist:
            return .other
        case .requiredentitlementnotpresent:
            return .other
        }
    }

    var code: Int {
        switch self {
        case .unknown: return -1
        case .alreadyExists: return -2
        case .couldNotFound: return -3
        case .incorrectPassphrase: return -4
        case .parseFailed: return -5
        case .unknownOSStatus( _,  _): return -6
        case .unknownAccessControl( _): return -7
        case .other: return -1000
        }
    }

    var errorDescription: String? {
        switch self {
        case .unknown:
            return "unknown error."
        case .alreadyExists:
            return "The specified item already exists."
        case .couldNotFound:
            return "The specified item could not be found."
        case .incorrectPassphrase:
            return "The user name or passphrase you entered is not correct."
        case .parseFailed:
            return "failed to parse."
        case .unknownOSStatus(let value, let status):
            return "unknown OSStatus: \(value), \(status)"
        case .unknownAccessControl(let accessControl):
            return "unknown AccessControl: \(accessControl)"
        case .other:
            return "other error."
        }
    }
}
