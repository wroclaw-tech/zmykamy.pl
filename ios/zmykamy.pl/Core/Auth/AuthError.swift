import Foundation

nonisolated enum AuthError: LocalizedError, Equatable, Sendable {
    case invalidCredentials
    case userAlreadyExists
    case passwordTooShort
    case passwordTooLong
    case invalidEmail
    case validation(String)
    case unauthorized
    case network
    case server(status: Int, code: String?)

    init(status: Int, response: AuthErrorResponse?) {
        switch response?.code {
        case "INVALID_EMAIL_OR_PASSWORD", "INVALID_PASSWORD": self = .invalidCredentials
        case "USER_ALREADY_EXISTS", "USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL": self = .userAlreadyExists
        case "PASSWORD_TOO_SHORT": self = .passwordTooShort
        case "PASSWORD_TOO_LONG": self = .passwordTooLong
        case "INVALID_EMAIL": self = .invalidEmail
        case "VALIDATION_ERROR": self = .validation(response?.message ?? "")
        default: self = status == 401 ? .unauthorized : .server(status: status, code: response?.code)
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "Nieprawidłowy e-mail lub hasło."
        case .userAlreadyExists: "Konto z tym adresem e-mail już istnieje. Zaloguj się."
        case .passwordTooShort: "Hasło musi mieć co najmniej \(AuthClient.minPasswordLength) znaków."
        case .passwordTooLong: "Hasło jest za długie."
        case .invalidEmail: "Nieprawidłowy adres e-mail."
        case .validation: "Sprawdź wpisane dane i spróbuj ponownie."
        case .unauthorized: "Sesja wygasła. Zaloguj się ponownie."
        case .network: "Brak połączenia z serwerem. Spróbuj ponownie."
        case .server: "Coś poszło nie tak. Spróbuj ponownie za chwilę."
        }
    }
}
