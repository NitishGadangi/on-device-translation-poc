import Foundation

/// Selectable translation backends. Apple is live; ML Kit is a future-scope stub.
enum TranslationProvider: String, CaseIterable, Identifiable, Sendable {
    case apple
    case mlKit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: return "Apple Translation"
        case .mlKit: return "Google ML Kit (coming soon)"
        }
    }

    var isAvailable: Bool { self == .apple }
}

@MainActor
enum TranslatorFactory {
    static func make(_ provider: TranslationProvider,
                     coordinator: TranslationCoordinator) -> TextTranslator {
        switch provider {
        case .apple, .mlKit:
            return AppleTextTranslator(coordinator: coordinator)
        }
    }
}
