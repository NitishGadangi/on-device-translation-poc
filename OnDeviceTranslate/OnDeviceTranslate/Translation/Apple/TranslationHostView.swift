import SwiftUI
import Translation

/// A hidden, zero-size view that lives at the app root. Its `.translationTask` is
/// the only place a `TranslationSession` can be obtained, so it forwards each
/// session to the coordinator to drain queued work. Must stay mounted for the
/// app's lifetime — if it unmounts, queued translations would never resume.
struct TranslationHostView: View {
    @ObservedObject var coordinator: TranslationCoordinator

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .translationTask(coordinator.configuration) { session in
                await coordinator.drain(using: session)
            }
    }
}
