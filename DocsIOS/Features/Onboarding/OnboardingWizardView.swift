import SwiftUI
import TODDAwardsKit
import TODDAuthKit
import TODDProfileKit

/// Pre-sign-in wizard shown instead of a cold sign-in wall: the user writes
/// their first Q&A answer (a Knowledge Base response flow) - one decision
/// per screen, each pre-filled with a sensible default - then name and
/// company, and signs in last. Same pattern as pulse-ios's
/// PreAuthSurveyBuilderView and network-ios's OnboardingWizardView; see
/// ONBOARDING-PROFILE-BILLING-PLAYBOOK.md. AuthService saves both after
/// sign-in (`submitOnboardingIfNeeded`).
struct OnboardingWizardView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var awardsService: AwardsService
    @State private var step: WizardStep = .intro
    @State private var draft = FirstAnswerDraft.load()
    @State private var profile = AuthService.profileStore.load()
    /// "Already have an account? Sign in" swaps to SignInView in place.
    @State private var isShowingSignInOnly = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        Group {
            if isShowingSignInOnly {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            isShowingSignInOnly = false
                        } label: {
                            Label("Back", systemImage: "chevron.left").font(.body.weight(.semibold))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    SignInView(authService: authService)
                }
            } else {
                wizard
            }
        }
        .onChange(of: profile) { _, value in AuthService.profileStore.save(value) }
        .onChange(of: draft) { _, value in value.save() }
    }

    private var wizard: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding()
            }
            VStack(spacing: 10) {
                footer
                if step != .signUp {
                    Button("Already have an account? Sign in") { isShowingSignInOnly = true }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 560)
            .padding()
        }
        .animation(.default, value: step)
        .onChange(of: step) { _, newStep in
            if newStep == .preview {
                awardsService.recordFirstAnswerWritten()
            }
            if newStep == .signUp {
                profile.isReadyToSubmit = true
                draft.isReadyToSubmit = true
            }
            isFieldFocused = [.firstName, .lastName, .company].contains(newStep)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                if let back = step.back {
                    Button {
                        step = back
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Back")
                }
                Spacer()
            }
            .frame(height: 32)
            WizardProgressBar(step: step)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Content per step

    @ViewBuilder
    private var content: some View {
        switch step {
        case .intro:
            VStack(alignment: .leading, spacing: 10) {
                Text("You're already 1 step in")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DocsTheme.accent)
                Text("Let's write down your best answer")
                    .font(.largeTitle.bold())
                Text("Pick a question customers ask you, and Docs keeps your answer ready for proposals, emails and Maya. Sign-in comes at the very end.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .question:
            VStack(alignment: .leading, spacing: 14) {
                Text("What do customers ask you most?")
                    .font(.title2.bold())
                ChipFlow(spacing: 8) {
                    ForEach(StarterQuestion.allCases) { starter in
                        chip(starter.label, isSelected: draft.starter == starter) {
                            draft.choose(starter)
                            isFieldFocused = starter == .other
                        }
                    }
                }
                if draft.starter == .other {
                    boxedField("Type the question", text: $draft.question)
                        .focused($isFieldFocused)
                }
            }

        case .answer:
            VStack(alignment: .leading, spacing: 14) {
                Text("How do you answer it?")
                    .font(.title2.bold())
                Text(draft.starter == .other ? "Answer the way you would on a call." : "We started it for you - change anything so it sounds like you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(draft.trimmedQuestion)
                    .font(.headline)
                TextField("Your answer", text: $draft.answer, axis: .vertical)
                    .lineLimit(4...10)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.15)))
            }

        case .preview:
            VStack(alignment: .leading, spacing: 14) {
                Text("Here's your first answer")
                    .font(.title2.bold())
                Text("It goes into your Knowledge Base, ready to reuse. Sign up and it's saved to your account.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                AnswerPreviewCard(draft: draft)
            }

        case .firstName:
            nameStep("What's your first name?", hint: "So your documents know who wrote them.", text: $profile.firstName, placeholder: "First name", contentType: .givenName)

        case .lastName:
            nameStep("And your last name?", hint: nil, text: $profile.lastName, placeholder: "Last name", contentType: .familyName)

        case .company:
            nameStep("What's your company called?", hint: "It appears on proposals and documents you create.", text: $profile.companyName, placeholder: "Company name", contentType: .organizationName)

        case .signUp:
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.largeTitle)
                        .foregroundStyle(DocsTheme.accent)
                    Text(draft.trimmedQuestion)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("Your answer is ready - sign in to save it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 8)

                SignInView(authService: authService)
            }
        }
    }

    // MARK: - Footer (forward navigation)

    @ViewBuilder
    private var footer: some View {
        switch step {
        case .intro:
            primaryButton("Get started") { step = .question }
        case .question:
            primaryButton("Next") { step = .answer }
                .disabled(draft.trimmedQuestion.isEmpty)
        case .answer:
            primaryButton("Next") { step = .preview }
                .disabled(draft.trimmedAnswer.isEmpty)
        case .preview:
            VStack(spacing: 6) {
                primaryButton("Continue to sign up") { step = .firstName }
                Text("Free to start. Your answer is waiting right where you left it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .firstName:
            primaryButton("Next") { step = .lastName }
                .disabled(profile.firstName.trimmingCharacters(in: .whitespaces).isEmpty)
        case .lastName:
            primaryButton("Next") { step = .company }
                .disabled(profile.lastName.trimmingCharacters(in: .whitespaces).isEmpty)
        case .company:
            HStack(spacing: 10) {
                secondaryButton("Skip") { step = .signUp }
                primaryButton("Next") { step = .signUp }
            }
        case .signUp:
            EmptyView()
        }
    }

    // MARK: - Pieces

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark").font(.caption.weight(.bold))
                }
                Text(title).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(isSelected ? DocsTheme.accent : Color(.secondarySystemGroupedBackground)))
            .overlay(Capsule().strokeBorder(isSelected ? DocsTheme.accent : Color.primary.opacity(0.2), lineWidth: 1))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func boxedField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.title3)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.15)))
    }

    private func nameStep(_ title: String, hint: String?, text: Binding<String>, placeholder: String, contentType: UITextContentType) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title2.bold())
            if let hint {
                Text(hint).font(.subheadline).foregroundStyle(.secondary)
            }
            boxedField(placeholder, text: text)
                .textContentType(contentType)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isFieldFocused)
                .submitLabel(.next)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DocsTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DocsTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(DocsTheme.accent, lineWidth: 1.5))
                .foregroundStyle(DocsTheme.accent)
        }
    }
}

enum DocsTheme {
    static let accent = Color.blue
}

private enum WizardStep: Equatable {
    case intro, question, answer, preview, firstName, lastName, company, signUp

    /// The 4-segment progress bar: 0 Download (done before the wizard
    /// opens), 1 Your answer, 2 About you, 3 Sign up.
    var section: Int {
        switch self {
        case .intro, .question, .answer, .preview: return 1
        case .firstName, .lastName, .company: return 2
        case .signUp: return 3
        }
    }

    var back: WizardStep? {
        switch self {
        case .intro: return nil
        case .question: return .intro
        case .answer: return .question
        case .preview: return .answer
        case .firstName: return .preview
        case .lastName: return .firstName
        case .company: return .lastName
        case .signUp: return .company
        }
    }

    static let sectionOrder: [Int: [WizardStep]] = [
        1: [.intro, .question, .answer, .preview],
        2: [.firstName, .lastName, .company],
        3: [.signUp],
    ]
}

/// Download is already checked when the wizard opens - installing the app
/// was step one (endowed progress), same as network-ios's and pulse-ios's.
private struct WizardProgressBar: View {
    let step: WizardStep

    private static let titles = ["Download", "Your answer", "About you", "Sign up"]

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(0..<4, id: \.self) { index in
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DocsTheme.accent.opacity(0.18))
                            Capsule().fill(DocsTheme.accent).frame(width: geometry.size.width * fill(index))
                        }
                    }
                    .frame(height: 6)
                    HStack(spacing: 4) {
                        if fill(index) >= 1 {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(DocsTheme.accent)
                        }
                        Text(Self.titles[index]).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .font(.caption2.weight(index == step.section ? .bold : .medium))
                    .foregroundStyle(index <= step.section ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.section + 1) of 4, \(Self.titles[step.section])")
    }

    private func fill(_ index: Int) -> Double {
        if index < step.section { return 1 }
        if index > step.section { return 0 }
        let order = WizardStep.sectionOrder[step.section] ?? [step]
        let position = order.firstIndex(of: step) ?? 0
        return Double(position + 1) / Double(order.count + 1)
    }
}

/// The answer as it will read in the Knowledge Base.
private struct AnswerPreviewCard: View {
    let draft: FirstAnswerDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(draft.starter.category.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(DocsTheme.accent.opacity(0.12)))
                .foregroundStyle(DocsTheme.accent)
            Text(draft.trimmedQuestion)
                .font(.title3.bold())
            Text(draft.trimmedAnswer)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            if !draft.keywords.isEmpty {
                Text(draft.keywords.map { "#\($0)" }.joined(separator: "  "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color(.separator), lineWidth: 1))
    }
}

/// Wraps chips onto as many lines as they need.
private struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let isFirst = rows[rows.count - 1].indices.isEmpty
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += isFirst ? size.width : size.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
