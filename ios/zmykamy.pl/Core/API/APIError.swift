import Foundation

nonisolated struct APIErrorResponse: Decodable, Sendable {
    struct Body: Decodable, Sendable {
        let code: String?
        let message: String?
    }

    let error: Body
}

nonisolated enum APIError: LocalizedError, Equatable, Sendable {
    case unauthorized
    case forbidden
    case notFound
    case validation
    case network
    case server(status: Int, code: String?)

    init(status: Int, response: APIErrorResponse?) {
        switch status {
        case 400: self = .validation
        case 401: self = .unauthorized
        case 403: self = .forbidden
        case 404: self = .notFound
        default: self = .server(status: status, code: response?.error.code)
        }
    }

    var errorDescription: String? {
        switch self {
        case .unauthorized: "Sesja wygasła. Zaloguj się ponownie."
        case .forbidden: "Tylko organizator może to zrobić."
        case .notFound: "Ten wyjazd już nie istnieje albo nie masz do niego dostępu."
        case .validation: "Sprawdź wpisane dane i spróbuj ponownie."
        case .network: "Brak połączenia z serwerem. Spróbuj ponownie."
        case .server(_, "member_not_settled"): "Najpierw trzeba rozliczyć saldo tego uczestnika."
        case .server(_, "plan_points_out_of_range"): "Przenieś albo usuń punkty planu spoza nowych dat wyjazdu."
        case .server(_, "unsupported_currency"): "NBP nie publikuje kursu tej waluty. Wpisz własny kurs."
        case .server(_, "amount_too_large"): "Kwota po przeliczeniu jest za duża."
        case .server(_, "rate_unavailable"): "Nie udało się pobrać kursu NBP. Spróbuj ponownie lub wpisz własny kurs."
        case .server: "Coś poszło nie tak. Spróbuj ponownie za chwilę."
        }
    }
}
