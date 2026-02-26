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
        ScrollView {
            if viewModel.isLoading {
                LoadingView(title: "Loading Groop")
                    .frame(minHeight: 220)
                    .padding()
            } else if let groop = viewModel.groop {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard(for: groop)
                    quickActions(for: groop)

                    SurfaceCard {
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
                            HStack(spacing: 8) {
                                ForEach(viewModel.members.prefix(6)) { member in
                                    Circle()
                                        .fill(.thinMaterial)
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Text(initials(for: member.name))
                                                .font(.caption2.weight(.semibold))
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
                                SurfaceCard {
                                    Text(item.message)
                                        .font(.body)
                                    Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
                                    SurfaceCard {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "megaphone.fill")
                                                .foregroundStyle(.orange)
                                                .font(.subheadline)

                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(announcement.title)
                                                    .font(.headline)
                                                    .multilineTextAlignment(.leading)

                                                Text(announcement.body)
                                                    .font(.body)
                                                    .lineLimit(2)

                                                Text(announcement.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer(minLength: 8)
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    SurfaceCard {
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
                            Label("Join the chat", systemImage: "bubble.left.and.bubble.right.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding()
            } else {
                EmptyStateView(systemImage: "exclamationmark.triangle", title: "Groop Not Found", message: "This Groop may no longer be available.")
                    .padding()
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

    private func heroCard(for groop: Groop) -> some View {
        VStack(spacing: 10) {
            Text(groop.name)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                chipLabel(groop.category, systemImage: "tag.fill")
                chipLabel(groop.location, systemImage: "mappin.circle.fill")
            }

            chipLabel("\(groop.memberCount) members", systemImage: "person.2.fill")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(
            LinearGradient(
                colors: [
                    Color(uiColor: .systemTeal).opacity(0.35),
                    Color(uiColor: .systemBlue).opacity(0.28),
                    Color(uiColor: .systemIndigo).opacity(0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
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

    private func chipLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private func quickActions(for groop: Groop) -> some View {
        HStack(spacing: 10) {
            Button {
                isCreateSheetPresented = true
            } label: {
                actionTile(
                    title: "Post",
                    subtitle: "Announcement",
                    icon: "megaphone.fill",
                    isPrimary: true
                )
            }
            .buttonStyle(.plain)

            Button {
                router.navigate(to: .groopChat(groop.id, prefill: nil))
            } label: {
                actionTile(
                    title: "Open",
                    subtitle: "Groop Chat",
                    icon: "message.fill",
                    isPrimary: false
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func actionTile(title: String, subtitle: String, icon: String, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(isPrimary ? .white.opacity(0.85) : .secondary)
        }
        .foregroundStyle(isPrimary ? .white : .primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            isPrimary
                ? AnyShapeStyle(
                    LinearGradient(
                        colors: [Color(uiColor: .systemBlue), Color(uiColor: .systemTeal)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                : AnyShapeStyle(.regularMaterial),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}
