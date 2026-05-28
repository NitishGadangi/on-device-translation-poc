import SwiftUI

struct ArticleDetailView: View {
    let feedItem: FeedItem

    @EnvironmentObject private var api: APIClient
    @EnvironmentObject private var settings: DebugSettings
    @StateObject private var model = DetailViewModel()

    var body: some View {
        content
            .navigationTitle(feedItem.category)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: settings.reloadSignature) {
                await model.load(api: api)
            }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView("불러오는 중…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let article):
            ScrollView { articleBody(article) }
        case .failed(let message):
            ContentUnavailableView("불러오기 실패", systemImage: "wifi.slash", description: Text(message))
        }
    }

    private func articleBody(_ article: ArticleDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            AsyncImage(url: URL(string: article.heroImageUrl)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipped()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title).font(.title.bold())
                    Text(article.subtitle).font(.title3).foregroundStyle(.secondary)
                }

                AuthorCard(author: article.author, readMinutes: article.readMinutes)

                ForEach(Array(article.blocks.enumerated()), id: \.offset) { _, block in
                    BlockView(block: block)
                }

                if !article.relatedLinks.isEmpty {
                    Divider()
                    Text("관련 글").font(.headline)
                    ForEach(article.relatedLinks) { link in
                        Label(link.title, systemImage: "link")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 32)
    }
}

private struct AuthorCard: View {
    let author: ArticleAuthor
    let readMinutes: Int

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: author.avatarUrl)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(.quaternary)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(author.name).font(.subheadline.weight(.semibold))
                Text(author.bio).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Text("\(readMinutes) min").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct BlockView: View {
    let block: ContentBlock

    var body: some View {
        switch block.kind {
        case .heading:
            Text(block.text ?? "").font(.title3.bold()).padding(.top, 4)
        case .paragraph:
            Text(block.text ?? "").font(.body).lineSpacing(4)
        case .quote:
            VStack(alignment: .leading, spacing: 6) {
                Text(block.text ?? "").font(.body.italic())
                if let attribution = block.attribution {
                    Text("— \(attribution)").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                Rectangle().fill(.tint).frame(width: 3)
            }
        case .bullet:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(block.items ?? [], id: \.self) { item in
                    Label(item, systemImage: "circle.fill")
                        .labelStyle(BulletLabelStyle())
                        .font(.body)
                }
            }
        case .code:
            Text(block.text ?? "")
                .font(.system(.callout, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 5)).foregroundStyle(.tint)
            configuration.title
        }
    }
}
