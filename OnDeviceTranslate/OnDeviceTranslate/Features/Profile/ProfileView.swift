import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var api: APIClient
    @EnvironmentObject private var settings: DebugSettings
    @StateObject private var model = ProfileViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("프로필")
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
        case .loaded(let profile):
            List {
                Section { header(profile) }
                Section("배지") {
                    ForEach(profile.badges, id: \.self) { badge in
                        Label(badge, systemImage: "rosette")
                    }
                }
                Section("댓글 \(profile.comments.count)") {
                    ForEach(profile.comments) { comment in
                        CommentRow(comment: comment)
                    }
                }
            }
        case .failed(let message):
            ContentUnavailableView("불러오기 실패", systemImage: "wifi.slash", description: Text(message))
        }
    }

    private func header(_ profile: ProfileResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(profile.name).font(.title2.bold())
            Text(profile.handle).font(.subheadline).foregroundStyle(.secondary)
            Text(profile.bio).font(.body)
            Label(profile.location, systemImage: "mappin.and.ellipse")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 24) {
                stat("게시물", profile.stats.posts)
                stat("팔로워", profile.stats.followers)
                stat("팔로잉", profile.stats.following)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack {
            Text(value, format: .number.notation(.compactName))
                .font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct CommentRow: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.author).font(.subheadline.weight(.semibold))
                Spacer()
                Label("\(comment.likes)", systemImage: "heart")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if comment.text.isEmpty {
                Text("(내용 없음)").font(.body).foregroundStyle(.tertiary).italic()
            } else {
                Text(comment.text).font(.body)
            }
        }
        .padding(.vertical, 2)
    }
}
