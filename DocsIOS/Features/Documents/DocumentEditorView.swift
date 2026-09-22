import SwiftUI

struct DocumentEditorView: View {
    let apiClient: DocsAPIClient
    let document: TeamDocument?
    let onSaved: (TeamDocument) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(apiClient: DocsAPIClient, document: TeamDocument?, onSaved: @escaping (TeamDocument) -> Void) {
        self.apiClient = apiClient
        self.document = document
        self.onSaved = onSaved
        _title = State(initialValue: document?.title ?? document?.name ?? "")
        _content = State(initialValue: document?.htmlContent ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Document title", text: $title)
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 240)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(document == nil ? "New Document" : "Edit Document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let payload = DocumentPayload(name: title, title: title, htmlContent: content.isEmpty ? nil : content)

        do {
            let saved: TeamDocument
            if let document {
                saved = try await apiClient.updateDocument(id: document.id, payload: payload)
            } else {
                saved = try await apiClient.createDocument(payload)
            }
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
