import SwiftUI
import Observation

@MainActor
@Observable
final class AnnouncementDetailViewModel {
    enum RSVP: String, CaseIterable {
        case going
        case maybe
        case notGoing

        var title: String {
            switch self {
            case .going: return "Going"
            case .maybe: return "Maybe"
            case .notGoing: return "Not Going"
            }
        }
    }

    private let repository: GroopRepository
    let groopId: UUID
    let announcementId: UUID

    var groop: Groop?
    var announcement: Announcement?
    var members: [GroopMember] = []
    var isLoading = false
    var rsvp: RSVP = .going

    init(groopId: UUID, announcementId: UUID, repository: GroopRepository) {
        self.groopId = groopId
        self.announcementId = announcementId
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        groop = await repository.groop(id: groopId)
        announcement = await repository.announcement(id: announcementId)
        members = await repository.fetchMembers(for: groopId)
    }
}

struct AnnouncementDetailView: View {
    @State private var viewModel: AnnouncementDetailViewModel

    init(groopId: UUID, announcementId: UUID, repository: GroopRepository) {
        _viewModel = State(initialValue: AnnouncementDetailViewModel(groopId: groopId, announcementId: announcementId, repository: repository))
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                LoadingView(title: "Loading Announcement")
                    .frame(minHeight: 220)
                    .padding()
            } else if let announcement = viewModel.announcement {
                VStack(spacing: 14) {
                    heroCard(announcement)
                    rsvpCard
                    peopleCard
                    detailsCard(announcement)
                }
                .padding()
            } else {
                EmptyStateView(
                    systemImage: "megaphone",
                    title: "Announcement Not Found",
                    message: "This announcement may no longer be available."
                )
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
        .navigationTitle("Announcement")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private func heroCard(_ announcement: Announcement) -> some View {
        VStack(spacing: 8) {
            Text(announcement.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text(announcement.createdAt.formatted(date: .complete, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let groop = viewModel.groop {
                Text(groop.location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(uiColor: .systemRed).opacity(0.35),
                    Color(uiColor: .systemOrange).opacity(0.3),
                    Color(uiColor: .systemBlue).opacity(0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var rsvpCard: some View {
        SurfaceCard {
            Text("RSVP")
                .font(.headline)

            Picker("RSVP", selection: $viewModel.rsvp) {
                ForEach(AnnouncementDetailViewModel.RSVP.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var peopleCard: some View {
        SurfaceCard {
            HStack {
                Text("People")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.members.count) invited")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.members.prefix(10)) { member in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(.thinMaterial)
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Text(initials(for: member.name))
                                        .font(.caption.weight(.semibold))
                                )

                            Text(firstName(from: member.name))
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(width: 56)
                    }
                }
            }
        }
    }

    private func detailsCard(_ announcement: Announcement) -> some View {
        SurfaceCard {
            Text("Details")
                .font(.headline)

            Text(announcement.body)
                .font(.body)

            if let groop = viewModel.groop {
                Label(groop.location, systemImage: "mappin.and.ellipse")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined()
    }

    private func firstName(from name: String) -> String {
        name.components(separatedBy: " ").first ?? name
    }
}
