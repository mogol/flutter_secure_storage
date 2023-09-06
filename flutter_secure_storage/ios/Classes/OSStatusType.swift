enum OSStatusType: Int32 {
    case noError = 0
    case functionwerenotvalid = -50
    case incorrectPassphrase = -25293
    case alreadyExists = -25299
    case couldNotFound = -25300
    case attributedoesnotexist = -25303
    case requiredentitlementnotpresent = -34018

    var message: String {
        switch self {
        case .noError:
            return "No error."
        case .functionwerenotvalid:
            return "One or more parameters passed to a function were not valid."
        case .incorrectPassphrase:
            return "The user name or passphrase you entered is not correct."
        case .alreadyExists:
            return "The specified item already exists in the keychain."
        case .couldNotFound:
            return "The specified item could not be found in the keychain."
        case .attributedoesnotexist:
            return "The specified attribute does not exist."
        case .requiredentitlementnotpresent:
            return "A required entitlement isn’t present."
        }
    }
}
