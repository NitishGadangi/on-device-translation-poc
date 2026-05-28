import Foundation
import Combine

@MainActor
final class DetailViewModel: ObservableObject {
    @Published var state: LoadState<ArticleDetail> = .idle

    func load(api: APIClient) async {
        state = .loading
        do {
            state = .loaded(try await api.fetch(.detail))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
