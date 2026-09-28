import SwiftUI
import AVFoundation
import UIKit
import TODDAuthKit

struct DocumentListView: View {
    @ObservedObject var authService: AuthService
    @StateObject private var viewModel: DocumentListViewModel
    private let apiClient: DocsAPIClient
    @State private var searchTerm = ""
    @State private var sortNewestFirst = true
    @State private var selectedDocumentID: String?
    @State private var editingDocument: TeamDocument?
    @State private var isShowingStatus = false
    @State private var isShowingRepository = false
    @State private var isShowingLogoutConfirmation = false
    @State private var isShowingCreateWarning = false
    @State private var pendingDelete: TeamDocument?
    @State private var isOpeningWebHandoff = false
    @State private var webHandoffErrorMessage: String?

    private static let docsHost = URL(string: "https://docs.taliferro.tech")!

    /// Destinations reachable from the account menu via the shared
    /// `TODDAuthKit.WebHandoff` real-token handoff - opens already signed
    /// in, no second login. Mirrors outreach-ios's account menu.
    private static let webHandoffMenuItems: [(title: String, icon: String, path: String, host: URL)] = [
        (title: "Home", icon: "house", path: "/", host: docsHost),
        (title: "My Documents", icon: "folder", path: "/docs/documents", host: docsHost),
        (title: "Upload", icon: "arrow.up.doc", path: "/docs/upload", host: docsHost),
        (title: "Studio", icon: "pencil.and.outline", path: "/docs/editor", host: docsHost),
        (title: "Knowledge Base", icon: "book", path: "/knowledge", host: docsHost),
        (title: "Response Flow", icon: "arrow.triangle.branch", path: "/knowledge/response-flow", host: docsHost),
    ]

    init(apiClient: DocsAPIClient, authService: AuthService) {
        self.apiClient = apiClient
        self.authService = authService
        _viewModel = StateObject(wrappedValue: DocumentListViewModel(apiClient: apiClient))
    }

    var body: some View {
        NavigationSplitView {
            libraryPane
        } detail: {
            detailPane
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .onChange(of: viewModel.documents.count) { _, _ in
            if let selectedDocumentID, !viewModel.documents.contains(where: { $0.id == selectedDocumentID }) {
                self.selectedDocumentID = nil
            }
        }
        .sheet(item: $editingDocument) { document in
            DocumentEditorView(apiClient: apiClient, document: document) { updated in
                viewModel.upsert(updated)
            }
        }
        .fullScreenCover(isPresented: $isShowingStatus) {
            DocsStatusView(apiClient: apiClient)
        }
        .fullScreenCover(isPresented: $isShowingRepository) {
            RepositoryView(apiClient: apiClient)
        }
        .alert("Log out of Docs?", isPresented: $isShowingLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                try? authService.signOut()
            }
        } message: {
            Text("You can sign in again with your TODD account.")
        }
        .alert("Delete this document?", isPresented: .constant(pendingDelete != nil)) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let document = pendingDelete {
                    if selectedDocumentID == document.id {
                        selectedDocumentID = nil
                    }
                    Task { await viewModel.delete(document) }
                }
                pendingDelete = nil
            }
        } message: {
            Text(pendingDelete.map(documentTitle) ?? "")
        }
        .alert("You'll leave Docs", isPresented: $isShowingCreateWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                openWebHandoff(path: "/docs/upload", host: Self.docsHost)
            }
        } message: {
            Text("Uploading a new document opens docs.taliferro.tech in your browser, already signed in. You'll leave the app to do this.")
        }
        .alert("Couldn't open that page", isPresented: .constant(webHandoffErrorMessage != nil)) {
            Button("OK") { webHandoffErrorMessage = nil }
        } message: {
            Text(webHandoffErrorMessage ?? "")
        }
        .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var filteredDocuments: [TeamDocument] {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matchingDocuments: [TeamDocument]
        if term.isEmpty {
            matchingDocuments = viewModel.documents
        } else {
            matchingDocuments = viewModel.documents.filter { document in
                [documentTitle(document), document.name, document.type ?? "", document.status ?? ""]
                    .joined(separator: " ")
                    .lowercased()
                    .contains(term)
            }
        }

        return matchingDocuments.sorted { lhs, rhs in
            let lhsDate = documentDate(lhs.updatedAt ?? lhs.createdAt) ?? .distantPast
            let rhsDate = documentDate(rhs.updatedAt ?? rhs.createdAt) ?? .distantPast
            return sortNewestFirst ? lhsDate > rhsDate : lhsDate < rhsDate
        }
    }

    private var selectedDocument: TeamDocument? {
        guard let selectedDocumentID else { return nil }
        return viewModel.documents.first { $0.id == selectedDocumentID }
    }

    private var libraryPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search documents", text: $searchTerm)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchTerm.isEmpty {
                    Button {
                        searchTerm = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)

            HStack {
                Text("\(filteredDocuments.count) \(filteredDocuments.count == 1 ? "document" : "documents")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button {
                        sortNewestFirst = true
                    } label: {
                        Label("Newest first", systemImage: sortNewestFirst ? "checkmark" : "")
                    }
                    Button {
                        sortNewestFirst = false
                    } label: {
                        Label("Oldest first", systemImage: sortNewestFirst ? "" : "checkmark")
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            if viewModel.isLoading && viewModel.documents.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.documents.isEmpty {
                ContentUnavailableView {
                    Label("No documents yet", systemImage: "doc.text")
                } description: {
                    Text("Your documents will appear here.")
                } actions: {
                    Button("Upload a Document") { isShowingCreateWarning = true }
                        .buttonStyle(.borderedProminent)
                }
            } else if filteredDocuments.isEmpty {
                ContentUnavailableView("No documents found", systemImage: "magnifyingglass", description: Text("Try a different search."))
            } else {
                List(selection: $selectedDocumentID) {
                    ForEach(filteredDocuments) { document in
                        DocumentLibraryRow(document: document, isSelected: selectedDocumentID == document.id)
                            .tag(document.id)
                            .contextMenu {
                                Button {
                                    editingDocument = document
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    pendingDelete = document
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Documents")
    }

    /// The account menu lives on the detail pane's toolbar, not the
    /// sidebar's: on iPad's two-column layout, the sidebar's own trailing
    /// toolbar item lands at the right edge of the SIDEBAR (the middle of
    /// the screen), not the actual top-right corner of the window - the
    /// detail pane is the rightmost column, so its toolbar is what
    /// actually renders there.
    @ViewBuilder
    private var detailPane: some View {
        Group {
            if let document = selectedDocument {
                DocumentDetailPane(document: document)
            } else {
                ContentUnavailableView {
                    Label("Select a document", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Choose a document from the library to see its details and available actions.")
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                accountMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCreateWarning = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(isOpeningWebHandoff)
            }
        }
    }

    private var accountMenu: some View {
        Menu {
            ForEach(Self.webHandoffMenuItems, id: \.title) { item in
                Button {
                    openWebHandoff(path: item.path, host: item.host)
                } label: {
                    Label(item.title, systemImage: item.icon)
                }
                .disabled(isOpeningWebHandoff)
            }
            Divider()
            Button {
                isShowingStatus = true
            } label: {
                Label("Status", systemImage: "gauge.medium")
            }
            Button {
                isShowingRepository = true
            } label: {
                Label("My Knowledge Base", systemImage: "book.closed")
            }
            Button(role: .destructive) {
                isShowingLogoutConfirmation = true
            } label: {
                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Label("Account", systemImage: "person.crop.circle")
                .labelStyle(.iconOnly)
        }
        .accessibilityLabel("Account menu")
    }

    /*
     The list/detail presentation deliberately stays on TeamDocument and the
     existing view model. The mobile API currently exposes text-document
     fields only, so unsupported media gets a calm type tile until those
     sources are added to the mobile response.
     */
    private func documentTitle(_ document: TeamDocument) -> String {
        document.title?.isEmpty == false ? document.title! : document.name
    }

    private static let isoFormatter = ISO8601DateFormatter()

    /// Opens a web page already signed in via the shared
    /// `TODDAuthKit.WebHandoff` real-token handoff - no second login.
    private func openWebHandoff(path: String, host: URL) {
        isOpeningWebHandoff = true
        Task {
            defer { isOpeningWebHandoff = false }
            do {
                let idToken = try await authService.freshIdToken()
                try await WebHandoff.open(
                    path: path,
                    idToken: idToken,
                    apiBaseURL: AppConfig.fromBundle().apiBaseURL,
                    webBaseURL: host
                )
            } catch {
                webHandoffErrorMessage = "Please try again in a moment."
            }
        }
    }
}

private struct DocumentLibraryRow: View {
    let document: TeamDocument
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            DocumentPreview(document: document, compact: true)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title?.isEmpty == false ? document.title! : document.name)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Text(documentTypeLabel)
                    if let topic = document.topic, !topic.isEmpty {
                        Text("·")
                        Text(topic)
                    }
                    if let status = document.status, !status.isEmpty {
                        Text("·")
                        Text(status.capitalized)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let date = formattedDate(document.updatedAt ?? document.createdAt) {
                    Text("Updated \(date)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(document.title ?? document.name), \(documentTypeLabel)")
    }

    private var documentTypeLabel: String {
        let type = document.type?.trimmingCharacters(in: .whitespacesAndNewlines)
        return type?.isEmpty == false ? type!.capitalized : "Document"
    }
}

private struct DocumentDetailPane: View {
    let document: TeamDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZStack {
                    DocumentPreview(document: document, compact: false)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .clipped()

                VStack(alignment: .leading, spacing: 10) {
                    Text(documentTypeLabel.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text(document.title?.isEmpty == false ? document.title! : document.name)
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let status = document.status, !status.isEmpty {
                        Label(status.capitalized, systemImage: "circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                metadata
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Document details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 14) {
            metadataRow("Type", value: documentTypeLabel, icon: "doc.text")
            if let topic = nonEmpty(document.topic) {
                metadataRow("Category", value: topic, icon: "folder")
            }
            if let author = nonEmpty(document.author) {
                metadataRow("Author", value: author, icon: "person")
            }
            if let added = formattedDate(document.uploadDate ?? document.createdAt) {
                metadataRow("Date added", value: added, icon: "calendar.badge.plus")
            }
            if let updated = formattedDate(document.updatedAt) {
                metadataRow("Updated", value: updated, icon: "clock")
            }
            if let summary = nonEmpty(document.summary) {
                metadataRow("Summary", value: summary, icon: "text.alignleft")
            } else if let description = nonEmpty(document.description) {
                metadataRow("Description", value: description, icon: "text.alignleft")
            }
            if document.htmlContent?.isEmpty == false {
                metadataRow("Content", value: "Text document", icon: "text.alignleft")
            }
            if let posted = formattedDate(document.lastPostedAt) {
                let platforms = document.lastPostedPlatforms.isEmpty ? "Posted" : "Posted to \(document.lastPostedPlatforms.joined(separator: ", "))"
                metadataRow("Social", value: "\(platforms) · \(posted)", icon: "paperplane")
            }
        }
    }

    private func metadataRow(_ label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var documentTypeLabel: String {
        let type = document.type?.trimmingCharacters(in: .whitespacesAndNewlines)
        return type?.isEmpty == false ? type!.capitalized : "Document"
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}

private struct DocumentPreview: View {
    let document: TeamDocument
    let compact: Bool

    var body: some View {
        Group {
            if isImage, let url = sourceURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: compact ? .fill : .fit)
                            .padding(compact ? 0 : 12)
                    } else {
                        typeTile
                    }
                }
            } else if isVideo, let url = sourceURL {
                VideoThumbnailView(url: url, compact: compact)
            } else {
                typeTile
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 12 : 20, style: .continuous))
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: compact ? 12 : 20, style: .continuous))
    }

    private var typeTile: some View {
        RoundedRectangle(cornerRadius: compact ? 12 : 20, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay {
                VStack(spacing: compact ? 5 : 12) {
                    Image(systemName: iconName)
                        .font(.system(size: compact ? 25 : 68, weight: .medium))
                        .foregroundStyle(.secondary)
                    if !compact {
                        Text(documentTypeLabel)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
    }

    private var documentTypeLabel: String {
        let type = document.type?.trimmingCharacters(in: .whitespacesAndNewlines)
        return type?.isEmpty == false ? type!.capitalized : "Document"
    }

    private var iconName: String {
        switch document.type?.lowercased() {
        case "pdf": return "doc.richtext"
        case "doc", "docx", "word": return "doc.text"
        case "xls", "xlsx", "excel": return "tablecells"
        case "ppt", "pptx", "powerpoint": return "rectangle.on.rectangle"
        case "image", "jpg", "jpeg", "png": return "photo"
        case "video", "mov", "mp4": return "play.rectangle"
        case "audio", "mp3": return "waveform"
        default: return "doc.text"
        }
    }

    private var sourceURL: URL? {
        guard let source = document.src, !source.isEmpty else { return nil }
        return URL(string: source)
    }

    private var isImage: Bool {
        let value = "\(document.type ?? "") \(document.mimeType ?? "")".lowercased()
        return value.contains("image") || value.contains("png") || value.contains("jpg") || value.contains("jpeg") || value.contains("gif")
    }

    private var isVideo: Bool {
        let value = "\(document.type ?? "") \(document.mimeType ?? "")".lowercased()
        return value.contains("video") || value.contains("mp4") || value.contains("mov") || value.contains("m4v")
    }
}

private struct VideoThumbnailView: View {
    let url: URL
    let compact: Bool
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: compact ? .fill : .fit)
                    .padding(compact ? 0 : 12)
            }
            Image(systemName: "play.circle.fill")
                .font(.system(size: compact ? 24 : 60))
                .foregroundStyle(.white, .black.opacity(0.45))
        }
        .task(id: url) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, _ in
            guard let image else { return }
            Task { @MainActor in
                thumbnail = UIImage(cgImage: image)
            }
        }
    }
}

private func formattedDate(_ value: String?) -> String? {
    guard let date = documentDate(value) else { return nil }
    return date.formatted(date: .abbreviated, time: .omitted)
}

private func documentDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    return ISO8601DateFormatter().date(from: value)
}

/*
Legacy carousel removed: the iPad document workspace now uses a persistent
library and detail pane instead of one-document-at-a-time navigation.
*/
/*
            .toolbar {
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(Self.webHandoffMenuItems, id: \.title) { item in
                            Button {
                                openWebHandoff(path: item.path, host: item.host)
                            } label: {
                                Label(item.title, systemImage: item.icon)
                            }
                            .disabled(isOpeningWebHandoff)
                        }
                        Divider()
                        Button {
                            isShowingStatus = true
                        } label: {
                            Label("Status", systemImage: "gauge.medium")
                        }
                        Button {
                            isShowingRepository = true
                        } label: {
                            Label("My Knowledge Base", systemImage: "book.closed")
                        }
                        Button(role: .destructive) {
                            isShowingLogoutConfirmation = true
                        } label: {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Label("Account", systemImage: "person.crop.circle")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("Account menu")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingNewDocument = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .onChange(of: viewModel.documents.count) { _, newCount in
                if currentIndex >= newCount {
                    currentIndex = max(0, newCount - 1)
                }
            }
            .sheet(item: $editingDocument) { document in
                DocumentEditorView(apiClient: apiClient, document: document) { updated in
                    viewModel.upsert(updated)
                }
            }
            .sheet(isPresented: $isPresentingNewDocument) {
                DocumentEditorView(apiClient: apiClient, document: nil) { created in
                    viewModel.upsert(created)
                }
            }
            .sheet(isPresented: $isShowingStatus) {
                DocsStatusView(apiClient: apiClient)
            }
            .sheet(isPresented: $isShowingRepository) {
                RepositoryView(apiClient: apiClient)
            }
            .alert("Log out of Docs?", isPresented: $isShowingLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    try? authService.signOut()
                }
            } message: {
                Text("You can sign in again with your TODD account.")
            }
            .alert("Delete this document?", isPresented: .constant(pendingDelete != nil)) {
                Button("Cancel", role: .cancel) { pendingDelete = nil }
                Button("Delete", role: .destructive) {
                    if let document = pendingDelete {
                        Task { await viewModel.delete(document) }
                    }
                    pendingDelete = nil
                }
            } message: {
                Text(pendingDelete.map(documentTitle) ?? "")
            }
            .alert("Couldn't open that page", isPresented: .constant(webHandoffErrorMessage != nil)) {
                Button("OK") { webHandoffErrorMessage = nil }
            } message: {
                Text(webHandoffErrorMessage ?? "")
            }
            .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
*/

/*
    /// Swipeable card carousel - "one document at a time, swipe to move
    /// on" - adapted from the same visual language as the web marketing
    /// carousel, without its Open/Edit/Delete buttons: tapping a card
    /// opens the editor directly, and a long-press context menu offers
    /// delete instead, so the card itself stays clean.
    private func carousel(_ documents: [TeamDocument]) -> some View {
        VStack(spacing: 14) {
            TabView(selection: $currentIndex) {
                ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                    documentCard(document)
                        .padding(.horizontal, 20)
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

                Text("DOCUMENT \(currentIndex + 1) OF \(documents.count)")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)

                Button {
                    withAnimation { currentIndex = min(documents.count - 1, currentIndex + 1) }
                } label: {
                    Image(systemName: "chevron.right.circle.fill").font(.title2)
                }
                .disabled(currentIndex == documents.count - 1)
            }

            Menu {
                ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                    Button(documentTitle(document)) {
                        withAnimation { currentIndex = index }
                    }
                }
            } label: {
                HStack {
                    Text("JUMP TO DOCUMENT")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(documents[safe: currentIndex].map(documentTitle) ?? "")
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
    }

    private func documentCard(_ document: TeamDocument) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text((document.type?.isEmpty == false ? document.type! : "Document").uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.12), in: Capsule())
                .foregroundStyle(.blue)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .overlay(
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(documentTitle(document))
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                if let updatedAt = document.updatedAt, let date = Self.isoFormatter.date(from: updatedAt) {
                    Text("Updated \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let status = document.status, !status.isEmpty {
                    Text(status.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture { editingDocument = document }
        .contextMenu {
            Button {
                editingDocument = document
            } label: {
                Label("Open", systemImage: "square.and.pencil")
            }
            Button(role: .destructive) {
                pendingDelete = document
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func documentTitle(_ document: TeamDocument) -> String {
        document.title?.isEmpty == false ? document.title! : document.name
    }

    private static let isoFormatter = ISO8601DateFormatter()

    /// Opens a web page already signed in via the shared
    /// `TODDAuthKit.WebHandoff` real-token handoff - no second login.
    private func openWebHandoff(path: String, host: URL) {
        isOpeningWebHandoff = true
        Task {
            defer { isOpeningWebHandoff = false }
            do {
                let idToken = try await authService.freshIdToken()
                try await WebHandoff.open(
                    path: path,
                    idToken: idToken,
                    apiBaseURL: AppConfig.fromBundle().apiBaseURL,
                    webBaseURL: host
                )
            } catch {
                webHandoffErrorMessage = "Please try again in a moment."
            }
        }
    }
}
*/

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
