import SwiftUI

/// Small toolbar indicator showing whether content is currently being translated.
struct TranslationStatusBadge: View {
    @EnvironmentObject private var settings: DebugSettings

    var body: some View {
        let active = settings.isTranslationActive
        Label(active ? "EN" : "원문",
              systemImage: active ? "character.bubble.fill" : "character.bubble")
            .font(.caption2)
            .foregroundStyle(active ? Color.accentColor : Color.secondary)
    }
}
