import Foundation
import Combine

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var state: LoadState<FeedResponse> = .idle

    func load(api: APIClient) async {
        state = .loading
        do {
            state = .loaded(try await api.fetch(.feed))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
