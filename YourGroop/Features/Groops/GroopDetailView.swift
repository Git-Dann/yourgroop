import SwiftUI
import Observation

@MainActor
@Observable
final class GroopDetailViewModel {
    private let repository: GroopRepository
    let groopId: UUID

    var groop: Groop?
    var feedItems: [FeedItem] = []
    var announcements: [Announcement] = []
    var messages: [GroopMessage] = []
    var members: [GroopMember] = []
    var isLoading = false

    init(groopId: UUID, repository: GroopRepository) {
        self.groopId = groopId
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        groop = await repository.groop(id: groopId)
        feedItems = await repository.feedItems(for: groopId)
        announcements = await repository.fetchAnnouncements(for: groopId)
        messages = await repository.fetchMessages(for: groopId)
        members = await repository.fetchMembers(for: groopId)
    }

    func createAnnouncement(title: String, body: String) async {
        _ = await repository.createAnnouncement(groopId: groopId, title: title, body: body)
        announcements = await repository.fetchAnnouncements(for: groopId)
    }
}

struct GroopDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(AppRouter.self) private var router
    @State private var viewModel: GroopDetailViewModel
    @State private var isCreateSheetPresented = false

    init(groopId: UUID, repository: GroopRepository) {
        _viewModel = State(initialValue: GroopDetailViewModel(groopId: groopId, repository: repository))
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                if viewModel.isLoading {
                    LoadingView(title: "Loading Groop")
                        .frame(minHeight: 220)
                        .padding()
                } else if let groop = viewModel.groop {
                    VStack(alignment: .leading, spacing: 0) {
                        heroCard(for: groop, width: geo.size.width)

                        VStack(alignment: .leading, spacing: 16) {
                            quickActions(for: groop)

                            inviteCard {
                                HStack(alignment: .firstTextBaseline) {
                                    sectionTitle("Members", icon: "person.3.fill")
                                    Spacer()
                                    Button("See all") {
                                        router.navigate(to: .groopMembers(groop.id))
                                    }
                                    .font(.subheadline.weight(.medium))
                                }

                                if viewModel.members.isEmpty {
                                    Text("Members are loading.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    HStack(spacing: -6) {
                                        ForEach(viewModel.members.prefix(6)) { member in
                                            Circle()
                                                .fill(.thinMaterial)
                                                .frame(width: 34, height: 34)
                                                .overlay(
                                                    Text(initials(for: member.name))
                                                        .font(.caption2.weight(.semibold))
                                                )
                                                .overlay(
                                                    Circle().stroke(.white.opacity(0.7), lineWidth: 1)
                                                )
                                        }
                                    }

                                    if let host = viewModel.members.first(where: { $0.isHost }) {
                                        Text("Hosted by \(host.name)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                sectionTitle("Feed", icon: "bolt.fill")

                                if viewModel.feedItems.isEmpty {
                                    EmptyStateView(systemImage: "text.bubble", title: "No Feed Activity", message: "Activity updates will appear here.")
                                } else {
                                    ForEach(viewModel.feedItems) { item in
                                        infoRowCard(
                                            icon: "bolt.fill",
                                            iconColor: .blue,
                                            title: item.message,
                                            subtitle: groop.name,
                                            meta: item.timestamp.formatted(date: .abbreviated, time: .shortened)
                                        )
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                sectionTitle("Announcements", icon: "megaphone.fill")

                                if viewModel.announcements.isEmpty {
                                    EmptyStateView(systemImage: "megaphone", title: "No Announcements", message: "Post the first update for this Groop.")
                                } else {
                                    ForEach(viewModel.announcements) { announcement in
                                        Button {
                                            router.navigate(to: .announcementDetail(groopId: groop.id, announcementId: announcement.id))
                                        } label: {
                                            infoRowCard(
                                                icon: "megaphone.fill",
                                                iconColor: .orange,
                                                title: announcement.title,
                                                subtitle: announcement.body,
                                                meta: announcement.createdAt.formatted(date: .abbreviated, time: .shortened),
                                                cta: "Open"
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            inviteCard {
                                HStack {
                                    sectionTitle("Groop Chat", icon: "message.fill")
                                    Spacer()
                                    Text("\(viewModel.messages.count) chats")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let latest = viewModel.messages.last {
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(.thinMaterial)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Text(initials(for: latest.senderName))
                                                    .font(.caption2.weight(.semibold))
                                            )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(latest.senderName)
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(.secondary)
                                            Text(latest.body)
                                                .font(.subheadline)
                                                .lineLimit(2)
                                        }
                                    }
                                } else {
                                    Text("No messages yet. Say hi and start the conversation.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Button {
                                    router.navigate(to: .groopChat(groop.id, prefill: nil))
                                } label: {
                                    Label("Open chat", systemImage: "bubble.left.and.bubble.right.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                            }
                        }
                        .frame(width: geo.size.width - 32, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 18)
                    }
                } else {
                    EmptyStateView(systemImage: "exclamationmark.triangle", title: "Groop Not Found", message: "This Groop may no longer be available.")
                        .padding()
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle("Groop Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isCreateSheetPresented) {
            CreateAnnouncementView { title, body in
                Task { await viewModel.createAnnouncement(title: title, body: body) }
            }
            .presentationDetents([.medium, .large])
        }
        .task(id: viewModel.groopId) {
            await viewModel.load()
            await appModel.refreshAll()
        }
        .onAppear {
            Task { await viewModel.load() }
        }
    }

    private func heroCard(for groop: Groop, width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(heroImageName(for: groop))
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 430)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.58), .black.opacity(0.24), .clear],
                startPoint: .bottom,
                endPoint: .top
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(groop.name)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)

                Text("\(groop.category) • \(groop.location)")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)

                Text("\(groop.memberCount) members")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(18)
        }
        .frame(width: width, height: 430, alignment: .bottomLeading)
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined()
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .padding(.leading, 2)
    }

    private func quickActions(for groop: Groop) -> some View {
        HStack(spacing: 10) {
            Button {
                isCreateSheetPresented = true
            } label: {
                Label("Post", systemImage: "megaphone.fill")
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color(uiColor: .systemBlue), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button {
                router.navigate(to: .groopChat(groop.id, prefill: nil))
            } label: {
                Label("Open Chat", systemImage: "message.fill")
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(.thinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(.blue.opacity(0.22), lineWidth: 1)
                    )
                    .foregroundStyle(Color(uiColor: .systemBlue))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRowCard(icon: String, iconColor: Color, title: String, subtitle: String, meta: String, cta: String? = nil) -> some View {
        inviteCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let cta {
                    Text(cta)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    private func inviteCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
    }

    private func heroImageName(for groop: Groop) -> String {
        switch groop.category {
        case "Fitness":
            return "DiscoveryRunners"
        case "Books":
            return "DiscoveryBooks"
        case "Co-Working":
            return "DiscoveryCampfield"
        case "Games":
            return "DiscoveryGames"
        case "Arts":
            return "DiscoveryArts"
        default:
            return "LockHeroPhoto"
        }
    }
}
