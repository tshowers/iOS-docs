import SwiftUI

/// Status view for Docs, reached from the document list's account menu -
/// list stays the default screen on login (Docs is not the Outreach
/// exception). Native adaptation of `document-home.component.ts`'s
/// "Knowledge" cockpit: same four health meters, computed in
/// `DocsStatusViewModel` from the same document list already fetched for
/// the list screen. Mirrors network-ios's NetworkStatusView in structure
/// (command deck + health tile grid + diagnosis rows), presented as a
/// dismissible sheet like outreach-ios's "Messages Sent" rather than
/// full-screen.
struct DocsStatusView: View {
    @StateObject private var viewModel: DocsStatusViewModel
    @Environment(\.dismiss) private var dismiss

    init(apiClient: DocsAPIClient) {
        _viewModel = StateObject(wrappedValue: DocsStatusViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let summary = viewModel.summary {
                    dashboard(summary)
                } else if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .navigationTitle("Knowledge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }

    private func dashboard(_ summary: DocsStatusSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                commandDeck(summary)

                panel("Knowledge Health") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        healthTile("magnifyingglass", "Findability Health", summary.findabilityHealth, "\(summary.duplicateTitleCount) duplicate title(s)", .blue)
                        healthTile("clock.arrow.circlepath", "Knowledge Freshness", summary.knowledgeFreshness, "\(summary.staleDocumentCount) stale 90+ days", .orange)
                        healthTile("arrow.triangle.2.circlepath", "Proposal Reuse", summary.proposalReuse, "\(summary.proposalCount) proposal(s)", .green)
                        healthTile("tray.full.fill", "Capture Readiness", summary.captureReadiness, "\(summary.draftCount) draft(s) pending", .purple)
                    }
                }

                panel("Needs a decision") {
                    VStack(spacing: 14) {
                        diagnosisRow(
                            summary.duplicateTitleCount > 0 ? "Information is hard to find" : "Titles look unique",
                            value: summary.duplicateTitleCount,
                            detail: "documents appear to share duplicate titles",
                            tone: summary.duplicateTitleCount > 0 ? .orange : .green
                        )
                        diagnosisRow(
                            summary.staleDocumentCount > 0 ? "Knowledge is going stale" : "Knowledge looks fresh",
                            value: summary.staleDocumentCount,
                            detail: "documents have not been updated in 90+ days",
                            tone: summary.staleDocumentCount > 0 ? .yellow : .green
                        )
                        diagnosisRow(
                            summary.draftCount > 0 ? "Knowledge is stuck in draft" : "Nothing stuck in draft",
                            value: summary.draftCount,
                            detail: "draft documents still need to be finalized",
                            tone: summary.draftCount > 0 ? .orange : .green
                        )
                    }
                }
            }
            .padding(20)
        }
    }

    private func commandDeck(_ summary: DocsStatusSummary) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("TODD COMMAND DECK")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.blue)
                Text("Knowledge")
                    .font(.largeTitle.weight(.bold))
                Text("See what proof is missing, what TODD is organizing, and what knowledge is compounding.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 20)
            VStack(alignment: .trailing, spacing: 4) {
                Text("KNOWLEDGE SCORE")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Text("\(summary.knowledgeScore)%")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
            }
        }
        .padding(22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func healthTile(_ icon: String, _ title: String, _ value: Int, _ detail: String, _ accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon).font(.title3).foregroundStyle(accent)
            Text("\(value)%").font(.system(size: 28, weight: .bold, design: .rounded))
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ProgressView(value: Double(value), total: 100).tint(accent)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func diagnosisRow(_ title: String, value: Int, detail: String, tone: Color) -> some View {
        HStack(spacing: 14) {
            Circle().fill(tone).frame(width: 14, height: 14).shadow(color: tone.opacity(0.55), radius: 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text("\(value) \(detail)").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
