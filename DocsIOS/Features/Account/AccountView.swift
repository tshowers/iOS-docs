import SwiftUI
import TODDAwardsKit
import TODDProfileKit

enum AccountPage: Hashable {
    case gettingStarted, profile, awards
}

/// Full-screen account area (like Docs' Status and Knowledge Base
/// screens) with its own NavigationStack, so Getting Started, Profile and
/// Awards are pushed pages with back buttons - never sheets. Opening it
/// from the menu pushes the chosen page straight away; Back lands on this
/// list, Done returns to the library.
struct AccountView: View {
    let authService: AuthService
    @ObservedObject var awardsService: AwardsService
    let onOpenWeb: (_ path: String, _ host: URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var path: [AccountPage]

    static let docsHost = URL(string: "https://docs.taliferro.tech")!
    static let toddHost = URL(string: "https://todd.taliferro.tech")!
    static let showAtStartupKey = "docs.gettingStarted.showAtStartup"

    init(start: AccountPage?, authService: AuthService, awardsService: AwardsService, onOpenWeb: @escaping (_ path: String, _ host: URL) -> Void) {
        self.authService = authService
        self.awardsService = awardsService
        self.onOpenWeb = onOpenWeb
        _path = State(initialValue: start.map { [$0] } ?? [])
    }

    static func gettingStartedAPI(authService: AuthService) -> GettingStartedAPI {
        GettingStartedAPI(
            baseURL: AppConfig.fromBundle().apiBaseURL,
            path: "getting-started/docs",
            idToken: { @MainActor [weak authService] in
                guard let authService else { throw AuthServiceError.notSignedIn }
                return try await authService.freshIdToken()
            }
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                NavigationLink(value: AccountPage.gettingStarted) {
                    Label("Getting Started", systemImage: "checklist")
                }
                NavigationLink(value: AccountPage.profile) {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                NavigationLink(value: AccountPage.awards) {
                    Label("Awards", systemImage: "rosette")
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: AccountPage.self) { page in
                switch page {
                case .gettingStarted: gettingStartedView
                case .profile: profileView
                case .awards:
                    AwardsGridView(awardsService: awardsService)
                        .task { await awardsService.sync() }
                }
            }
        }
    }

    private var gettingStartedView: some View {
        GettingStartedView(
            api: Self.gettingStartedAPI(authService: authService),
            appName: "Docs",
            accent: DocsTheme.accent,
            showAtStartupKey: Self.showAtStartupKey,
            destination: { stepId in
                stepId == "profile" ? AnyView(profileView) : nil
            },
            onSelect: { stepId in
                switch stepId {
                case "firstAnswer": onOpenWeb("/knowledge/response-flow", Self.docsHost)
                case "addDocument": onOpenWeb("/docs/upload", Self.docsHost)
                case "mayaAnswer": onOpenWeb("/knowledge", Self.docsHost)
                default: break
                }
            }
        )
    }

    /// The shared in-app profile screen (TODDProfileKit) - also where the
    /// App Store-required "Delete account" lives.
    private var profileView: some View {
        let authService = self.authService
        return ProfileView(
            api: ProfileAPI(
                baseURL: AppConfig.fromBundle().apiBaseURL,
                idToken: { @MainActor [weak authService] in
                    guard let authService else { throw AuthServiceError.notSignedIn }
                    return try await authService.freshIdToken()
                }
            ),
            appName: "Docs",
            accent: DocsTheme.accent,
            onOpenWebSettings: { onOpenWeb("/update-profile", Self.toddHost) },
            onAccountDeleted: {
                AuthService.profileStore.clear()
                FirstAnswerDraft.clear()
                try? authService.signOut()
            }
        ) {
            Color(.systemGroupedBackground)
        }
    }
}
