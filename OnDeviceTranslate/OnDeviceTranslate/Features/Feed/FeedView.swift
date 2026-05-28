import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var api: APIClient
    @EnvironmentObject private var settings: DebugSettings
    @StateObject private var model = FeedViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navigationTitle)
                .navigationDestination(for: FeedItem.self) { item in
                    ArticleDetailView(feedItem: item)
                }
                .toolbar { TranslationStatusBadge() }
        }
        .task(id: settings.reloadSignature) {
            await model.load(api: api)
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView("불러오는 중…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let response):
            List {
                Section {
                    ForEach(response.items) { item in
                        NavigationLink(value: item) { FeedRow(item: item) }
                    }
                } header: {
                    Text(response.subtitle)
                }
            }
            .listStyle(.plain)
        case .failed(let message):
            ContentUnavailableView("불러오기 실패", systemImage: "wifi.slash", description: Text(message))
        }
    }

    private var navigationTitle: String {
        if case .loaded(let response) = model.state { return response.screenTitle }
        return "Feed"
    }
}

private struct FeedRow: View {
    let item: FeedItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: item.thumbnailUrl)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.category.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                if !item.summary.isEmpty {
                    Text(item.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 10) {
                    Label("\(item.likeCount)", systemImage: "heart")
                    Label("\(item.commentCount)", systemImage: "bubble.right")
                    Label("\(item.readMinutes) min", systemImage: "clock")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
