import SwiftUI

/// Shown right after sign-in when the wizard built an answer: the user
/// sees what they wrote, can still tweak it, and taps Save - same as
/// pulse-ios opening the pre-sign-in survey in the builder. "Not now"
/// keeps the draft for next launch.
struct FirstAnswerSaveView: View {
    let apiClient: DocsAPIClient
    let onFinished: (_ saved: Bool) -> Void
    @State private var draft = FirstAnswerDraft.load()
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Save your first answer")
                        .font(.largeTitle.bold())
                    Text("Here's what you wrote before signing in. Change anything you like, then save it to your Knowledge Base.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    field("Question") {
                        TextField("Question", text: $draft.question, axis: .vertical)
                            .lineLimit(1...3)
                    }
                    field("Your answer") {
                        TextField("Your answer", text: $draft.answer, axis: .vertical)
                            .lineLimit(4...12)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if !draft.isComplete {
                        Text("Add a question and an answer to save.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { onFinished(false) }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                            .disabled(!draft.isComplete)
                    }
                }
            }
            .onChange(of: draft) { _, value in value.save() }
        }
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.15)))
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await apiClient.createKnowledgeBaseEntry(draft.createPayload)
            FirstAnswerDraft.clear()
            onFinished(true)
        } catch {
            errorMessage = "Couldn't save your answer. Check your connection and try again."
        }
    }
}
