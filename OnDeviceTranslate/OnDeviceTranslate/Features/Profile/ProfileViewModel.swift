import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var state: LoadState<ProfileResponse> = .idle

    func load(api: APIClient) async {
        state = .loading
        do {
            state = .loaded(try await api.fetch(.profile))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
