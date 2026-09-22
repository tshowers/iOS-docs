import Foundation

struct AppConfig {
    let apiBaseURL: URL
    let docsProductId: String

    static func fromBundle(bundle: Bundle = .main) -> AppConfig {
        let baseURLString = bundle.object(forInfoDictionaryKey: "DOCS_API_BASE_URL") as? String ?? ""
        let docsProductId = bundle.object(forInfoDictionaryKey: "DOCS_APP_STORE_PRODUCT_ID") as? String ?? ""

        guard let apiBaseURL = URL(string: baseURLString) else {
            fatalError("Missing DOCS_API_BASE_URL in app configuration.")
        }

        return AppConfig(apiBaseURL: apiBaseURL, docsProductId: docsProductId)
    }
}
