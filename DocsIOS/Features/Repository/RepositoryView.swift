import SwiftUI

/// Native port of `repository.component.ts` ("Knowledge Base"): browse,
/// search, and delete saved response-flow entries, styled to match the
/// web card layout (question, evidence summary with sourced answers,
/// recommendations, resources, keywords). Shows one entry at a time via
/// paging rather than a multi-card scroll - reading a knowledge article
/// works better focused on one at a time than scanning several at once,
/// per explicit request; same "Article X of N" + prev/next pattern as
/// docs-ios's document carousel. Scoped to read + search + delete +
/// copy-citation - the web page's #/edit/delete icon row is left off each
/// card by request; delete is still reachable via a long-press context
/// menu instead, so the capability isn't lost, just off the card face.
/// The create/edit flow lives in a separate, much larger response-flow
/// builder component that isn't part of this port, and "turn into social
/// post" is Outreach-specific, out of scope for docs-ios.
struct RepositoryView: View {
    @StateObject private var viewModel: RepositoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: KnowledgeBaseEntry?
    @State private var copiedMessage: String?
    @State private var currentIndex = 0

    init(apiClient: DocsAPIClient) {
        _viewModel = StateObject(wrappedValue: RepositoryViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    ProgressView()
                } else if viewModel.entries.isEmpty {
                    ContentUnavailableView("No knowledge base entries yet", systemImage: "book.closed", description: Text("Saved response flows will show up here."))
                } else if viewModel.filteredEntries.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    VStack(spacing: 10) {
                        TabView(selection: $currentIndex) {
                            ForEach(Array(viewModel.filteredEntries.enumerated()), id: \.element.id) { index, entry in
                                ScrollView {
                                    entryCard(entry)
                                        .frame(maxWidth: 760)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 40)
                                        .padding(.vertical, 16)
                                }
                                .refreshable { await viewModel.load() }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))

                        HStack(spacing: 24) {
                            Button {
                                withAnimation { currentIndex = max(0, currentIndex - 1) }
                            } label: {
                                Image(systemName: "chevron.left.circle.fill").font(.title2)
                            }
                            .disabled(currentIndex == 0)

                            Text("ARTICLE \(currentIndex + 1) OF \(viewModel.filteredEntries.count)")
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(.secondary)

                            Button {
                                withAnimation { currentIndex = min(viewModel.filteredEntries.count - 1, currentIndex + 1) }
                            } label: {
                                Image(systemName: "chevron.right.circle.fill").font(.title2)
                            }
                            .disabled(currentIndex == viewModel.filteredEntries.count - 1)
                        }
                        .padding(.bottom, 10)
                    }
                }
            }
            .navigationTitle("Knowledge Base")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search knowledge base")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .onChange(of: viewModel.filteredEntries.count) { _, newCount in
                if currentIndex >= newCount {
                    currentIndex = max(0, newCount - 1)
                }
            }
            .alert("Delete this entry?", isPresented: .constant(pendingDelete != nil)) {
                Button("Cancel", role: .cancel) { pendingDelete = nil }
                Button("Delete", role: .destructive) {
                    if let entry = pendingDelete {
                        Task { await viewModel.delete(entry) }
                    }
                    pendingDelete = nil
                }
            } message: {
                Text(pendingDelete?.question ?? "")
            }
            .alert("Something went wrong", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
                Button("OK") { viewModel.errorMessage = "" }
            } message: {
                Text(viewModel.errorMessage)
            }
            .overlay(alignment: .bottom) {
                if let copiedMessage {
                    Text(copiedMessage)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 16)
                        .transition(.opacity)
                }
            }
        }
    }

    private func entryCard(_ entry: KnowledgeBaseEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(entry.question)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            if !entry.answers.isEmpty {
                cardSection("Evidence Summary") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(entry.answers.enumerated()), id: \.element.id) { index, answer in
                            answerView(index + 1, answer)
                        }
                    }
                }
            }

            if !entry.recommendations.isEmpty {
                cardSection("Recommendations") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.recommendations) { recommendation in
                            recommendationView(recommendation)
                        }
                    }
                }
            }

            if !entry.resources.isEmpty {
                cardSection("Resources") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(entry.resources) { resource in
                            resourceView(resource)
                        }
                    }
                }
            }

            if let keywords = entry.keywords, !keywords.isEmpty {
                cardSection("Keywords") {
                    chipWrap(keywords)
                }
            }

            HStack {
                if let category = entry.category, !category.isEmpty {
                    Text(category.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                }
                Spacer()
                if let reviewed = formattedDate(entry.updatedAt) {
                    Text("Reviewed \(reviewed)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.separator, lineWidth: 1))
        .contextMenu {
            Button(role: .destructive) {
                pendingDelete = entry
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func cardSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func answerView(_ number: Int, _ answer: KnowledgeBaseAnswer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(answer.answer)
                    .font(.subheadline)
            }
            HStack(spacing: 8) {
                if !answer.source.isEmpty {
                    Text(Self.domain(from: answer.source))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                    if let url = URL(string: answer.source) {
                        Link(destination: url) {
                            Text(answer.source)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                Button {
                    copyCitation(answer)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.leading, 2)
    }

    private func recommendationView(_ recommendation: KnowledgeBaseRecommendation) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if let type = recommendation.type, !type.isEmpty {
                Text(type)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(recommendationTint(type).opacity(0.15), in: Capsule())
                    .foregroundStyle(recommendationTint(type))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.text)
                    .font(.subheadline)
                if let url = URL(string: recommendation.link), !recommendation.link.isEmpty {
                    Link(recommendation.link, destination: url)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
    }

    private func recommendationTint(_ type: String) -> Color {
        switch type.lowercased() {
        case "resource": return .blue
        case "practice": return .green
        default: return .gray
        }
    }

    private func resourceView(_ resource: KnowledgeBaseResource) -> some View {
        Group {
            if let url = URL(string: resource.link) {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.caption)
                        Text(Self.domain(from: resource.link))
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func chipWrap(_ items: [String]) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12), in: Capsule())
                    .foregroundStyle(.blue)
            }
        }
    }

    private func copyCitation(_ answer: KnowledgeBaseAnswer) {
        UIPasteboard.general.string = viewModel.citation(for: answer)
        withAnimation { copiedMessage = "Citation copied" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copiedMessage = nil }
        }
    }

    private func formattedDate(_ value: String?) -> String? {
        guard let value, let date = ISO8601DateFormatter().date(from: value) else { return nil }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private static func domain(from urlString: String) -> String {
        guard let host = URL(string: urlString)?.host else { return urlString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

/// Minimal wrapping chip layout - SwiftUI has no built-in flow layout
/// before the `Layout` protocol (iOS 16+), which this app's iOS 17
/// deployment target supports directly.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > width, currentRowWidth > 0 {
                totalHeight += rowHeight + spacing
                currentRowWidth = 0
                rowHeight = 0
            }
            currentRowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.origin.x {
                origin.x = bounds.origin.x
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: origin, proposal: .unspecified)
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
