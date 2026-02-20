import SwiftUI

struct WelcomeView: View {
    var onSuggestionSelected: ((String) -> Void)?

    private let suggestions = [
        ("lightbulb.max", "Explain a concept", "Explain quantum computing in simple terms"),
        ("doc.text", "Help me write", "Help me draft a professional email"),
        ("wrench.and.screwdriver", "Debug code", "Find and fix the bug in this code"),
        ("list.bullet.clipboard", "Plan a project", "Help me create a project plan for a new app")
    ]

    var body: some View {
        VStack(spacing: TheaSpacing.xl) {
            Spacer()

            // Thea spiral icon — extracted spiral (no background) with CCW rotation + beat
            TheaSpiralIconView(size: 80, isThinking: false, showGlow: true)

            // Greeting with Thea's golden spiral brand colors
            VStack(spacing: TheaSpacing.sm) {
                Text(Self.timeBasedGreeting())
                    .font(.theaLargeDisplay)
                    .foregroundStyle(TheaBrandColors.spiralGradient)

                Text("How can I help you today?")
                    .font(.theaTitle2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(Self.timeBasedGreeting()) How can I help you today?")
            .accessibilityIdentifier("welcome-greeting")

            // Suggestion chips
            if onSuggestionSelected != nil {
                suggestionGrid
                    .padding(.horizontal, TheaSpacing.xxl)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var suggestionGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: TheaSpacing.md),
            GridItem(.flexible(), spacing: TheaSpacing.md)
        ], spacing: TheaSpacing.md) {
            ForEach(suggestions, id: \.2) { icon, title, prompt in
                Button {
                    onSuggestionSelected?(prompt)
                } label: {
                    HStack(spacing: TheaSpacing.sm) {
                        Image(systemName: icon)
                            .font(.theaBody)
                            .foregroundStyle(TheaBrandColors.gold)
                            .frame(width: 24)
                        Text(title)
                            .font(.theaSubhead)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(TheaSpacing.md)
                    .background(Color.theaSurface.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: TheaCornerRadius.md)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityHint("Sends the prompt: \(prompt)")
            }
        }
        .frame(maxWidth: 500)
    }

    static func timeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5 ..< 12:
            return "Good morning."
        case 12 ..< 17:
            return "Good afternoon."
        case 17 ..< 22:
            return "Good evening."
        default:
            return "Hello."
        }
    }
}

#Preview {
    WelcomeView()
}
