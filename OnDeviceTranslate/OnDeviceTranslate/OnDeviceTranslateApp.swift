import SwiftUI

@main
struct OnDeviceTranslateApp: App {
    @StateObject private var coordinator: TranslationCoordinator
    @StateObject private var settings: DebugSettings
    @StateObject private var api: APIClient

    init() {
        let coordinator = TranslationCoordinator()
        let settings = DebugSettings()
        let cache = TranslationCache()
        let translator = AppleTextTranslator(coordinator: coordinator)
        let responseTranslator = ResponseTranslator(translator: translator, cache: cache)
        let api = APIClient(network: NetworkService(),
                            responseTranslator: responseTranslator,
                            settings: settings,
                            cache: cache)
        _coordinator = StateObject(wrappedValue: coordinator)
        _settings = StateObject(wrappedValue: settings)
        _api = StateObject(wrappedValue: api)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(api)
                .environmentObject(settings)
                .environmentObject(coordinator)
                .background(TranslationHostView(coordinator: coordinator))
                .task {
                    await settings.refreshAvailability()
                    if settings.availability.allowsTranslation {
                        try? await coordinator.prepare(settings.availabilityProbePair)
                    }
                }
        }
    }
}
