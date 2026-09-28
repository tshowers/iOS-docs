import SwiftUI
import FirebaseAuth
import FirebaseCore
import TODDAuthKit
import TODDAwardsKit

@main
struct DocsIOSApp: App {
    @StateObject private var authService: AuthService
    @StateObject private var entitlementService: EntitlementService
    @StateObject private var awardsService: AwardsService
    private let apiClient: DocsAPIClient

    init() {
        FirebaseApp.configure()

        #if DEBUG
        try? Auth.auth().signOut()
        #endif

        let config = AppConfig.fromBundle()
        let authService = AuthService()
        _authService = StateObject(wrappedValue: authService)
        _awardsService = StateObject(wrappedValue: DocsAwards.makeService(authService: authService))
        let apiClient = DocsAPIClient(config: config, authService: authService)
        self.apiClient = apiClient
        _entitlementService = StateObject(wrappedValue: EntitlementService(
            apiClient: apiClient,
            authService: authService,
            config: config
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView(authService: authService, entitlementService: entitlementService, apiClient: apiClient, awardsService: awardsService)
                .onOpenURL { url in
                    _ = GoogleSignInHelper.handle(url)
                }
        }
    }
}
