import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject private var settings: DebugSettings
    @EnvironmentObject private var api: APIClient
    @State private var cacheCount = 0
    @State private var isClearing = false

    var body: some View {
        NavigationStack {
            Form {
                availabilitySection
                translationSection
                languageSection
                dataSection
                cacheSection
                statsSection
                logSection
            }
            .navigationTitle("Debug Settings")
            .task {
                await settings.refreshAvailability()
                cacheCount = await api.cacheCount()
            }
        }
    }

    @ViewBuilder private var availabilitySection: some View {
        if let message = settings.availability.message {
            Section {
                Label {
                    Text(message).font(.footnote)
                } icon: {
                    Image(systemName: settings.availability == .needsDownload
                          ? "arrow.down.circle" : "exclamationmark.triangle.fill")
                }
                .foregroundStyle(settings.availability == .needsDownload ? Color.blue : Color.orange)
            }
        }
    }

    private var translationSection: some View {
        Section("Translation") {
            Toggle("On-the-fly translation", isOn: $settings.translationEnabled)
                .disabled(!settings.availability.allowsTranslation)
            Picker("Provider", selection: $settings.provider) {
                ForEach(TranslationProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .onChange(of: settings.provider) { _, newValue in
                if !newValue.isAvailable { settings.provider = .apple }
            }
        }
    }

    private var languageSection: some View {
        Section("Language") {
            Picker("Source", selection: $settings.sourceMode) {
                ForEach(DebugSettings.SourceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            Picker("Target", selection: $settings.targetCode) {
                ForEach(DebugSettings.targetOptions, id: \.code) { option in
                    Text(option.name).tag(option.code)
                }
            }
            .onChange(of: settings.targetCode) { _, _ in
                Task { await settings.refreshAvailability() }
            }
        }
    }

    private var dataSection: some View {
        Section("Data Source") {
            Toggle("Use offline (bundled) JSON", isOn: $settings.useOfflineData)
            if !settings.useOfflineData {
                Text(NetworkConfig.rawBaseURL)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var cacheSection: some View {
        Section("Cache") {
            Toggle("Use translation cache", isOn: $settings.useCache)
            HStack {
                Text("Cached entries")
                Spacer()
                Text("\(cacheCount)").foregroundStyle(.secondary)
            }
            Button(role: .destructive) {
                Task {
                    isClearing = true
                    await api.clearCache()
                    cacheCount = await api.cacheCount()
                    isClearing = false
                }
            } label: {
                if isClearing { ProgressView() } else { Text("Clear cache") }
            }
        }
    }

    private var statsSection: some View {
        Section("Last Response Stats") {
            if let stats = settings.lastStats {
                statRow("Total strings", stats.totalStrings)
                statRow("Translated", stats.translatedStrings)
                statRow("Skipped", stats.skippedStrings)
                statRow("Cache hits", stats.cacheHits)
                HStack {
                    Text("Processing time")
                    Spacer()
                    Text(String(format: "%.0f ms", stats.processingTime * 1000))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No translation run yet.").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var logSection: some View {
        Section("Translation Log") {
            Toggle("Show original + translated", isOn: $settings.showOriginal)
            if settings.showOriginal {
                if let records = settings.lastStats?.records, !records.isEmpty {
                    ForEach(records.prefix(50)) { record in
                        LogRow(record: record)
                    }
                } else {
                    Text("No translated strings in the last response.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statRow(_ title: String, _ value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)").foregroundStyle(.secondary)
        }
    }
}

private struct LogRow: View {
    let record: TranslationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(record.detectedLanguage?.uppercased() ?? "?")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                if record.cacheHit {
                    Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.yellow)
                }
                Spacer()
            }
            Text(record.original).font(.caption).foregroundStyle(.secondary)
            Text(record.translated).font(.caption)
        }
        .padding(.vertical, 2)
    }
}
