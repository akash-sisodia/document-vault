import SwiftUI

#if canImport(FeedJarKit)
import FeedJarKit
#endif

enum FeedJarIntegration {
    static func configure() {
        #if canImport(FeedJarKit)
        let apiKey = AppConstants.feedJarAPIKey
        guard !apiKey.isEmpty else { return }
        FeedJar.configure(apiKey: apiKey)
        #endif
    }
}

struct FeedJarFeedbackButton: View {
    let label: String
    @State private var showFeedback = false

    var body: some View {
        Button {
            showFeedback = true
        } label: {
            Label(label, systemImage: "bubble.left.and.bubble.right.fill")
        }
        .fullScreenCover(isPresented: $showFeedback) {
            FeedJarFeedbackCover()
        }
    }
}

#if canImport(FeedJarKit)
private struct FeedJarFeedbackCover: View {
    var body: some View {
        FeedJarFeedbackSheet(allowedTypes: [.feedback, .featureRequest])
            .preferredColorScheme(.light)
            .ignoresSafeArea()
    }
}
#else
private struct FeedJarFeedbackCover: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Send Feedback")
                    .font(.headline)
                Text("Add the FeedJarKit package to enable the in-app feedback form.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
#endif
