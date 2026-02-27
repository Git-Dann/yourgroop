import SwiftUI
import Observation

@MainActor
@Observable
final class GroopMembersViewModel {
    private let repository: GroopRepository
    let groopId: UUID

    var members: [GroopMember] = []
    var isLoading = false

    init(groopId: UUID, repository: GroopRepository) {
        self.groopId = groopId
        self.repository = repository
    }

    var host: GroopMember? {
        members.first(where: { $0.isHost })
    }

    var attendees: [GroopMember] {
        members.filter { !$0.isHost }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        members = await repository.fetchMembers(for: groopId)
    }
}

struct GroopMembersView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel: GroopMembersViewModel
    @State private var recommendedMemberIDs: Set<UUID> = []
    @State private var recommendationTarget: GroopMember?
    @State private var recommendationNote = ""

    init(groopId: UUID, repository: GroopRepository) {
        _viewModel = State(initialValue: GroopMembersViewModel(groopId: groopId, repository: repository))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroSection

                if viewModel.isLoading {
                    LoadingView(title: "Loading members")
                        .frame(height: 120)
                } else {
                    if let host = viewModel.host {
                        sectionHeader("Host")
                        memberCard(host, highlight: true)
                    }

                    sectionHeader("Members")

                    if viewModel.attendees.isEmpty {
                        EmptyStateView(
                            systemImage: "person.3",
                            title: "No members yet",
                            message: "Members who join this groop will appear here."
                        )
                    } else {
                        ForEach(viewModel.attendees) { member in
                            memberCard(member, highlight: false)
                        }
                    }
                }
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle("Members")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $recommendationTarget) { member in
            recommendationSheet(for: member)
        }
        .task {
            await viewModel.load()
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("People in this groop")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Find collaborators by role, send a quick message, or recommend someone.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.84))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.members.prefix(8)) { member in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(.white.opacity(0.14))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(initials(for: member.name))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                )
                                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))

                            Text(firstName(from: member.name))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                        }
                        .frame(width: 58)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Color(red: 0.157, green: 0.180, blue: 0.537),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.leading, 2)
    }

    private func memberCard(_ member: GroopMember, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(.thinMaterial)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(initials(for: member.name))
                            .font(.caption.weight(.semibold))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(member.name)
                            .font(.headline)

                        if member.isHost {
                            Text("HOST")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(uiColor: .systemBlue).opacity(0.16), in: Capsule())
                        }
                    }

                    Text(member.jobTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(member.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                Button {
                    router.navigate(to: .groopChat(viewModel.groopId, prefill: "@\(member.name) "))
                } label: {
                    Label("Message", systemImage: "message.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(uiColor: .systemTeal), in: Capsule())

                Button {
                    recommendationTarget = member
                } label: {
                    if recommendedMemberIDs.contains(member.id) {
                        Label("Recommended", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Recommend", systemImage: "hand.thumbsup.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(recommendedMemberIDs.contains(member.id) ? Color.green : .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(.thinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            recommendedMemberIDs.contains(member.id) ? Color.green.opacity(0.3) : Color(uiColor: .separator).opacity(0.22),
                            lineWidth: 1
                        )
                )
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(highlight ? Color(uiColor: .systemBlue).opacity(0.32) : .white.opacity(0.18), lineWidth: 1)
        )
    }

    private func recommendationSheet(for member: GroopMember) -> some View {
        NavigationStack {
            Form {
                Section("Recommend \(member.name)") {
                    Text(member.jobTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Why would you recommend them?", text: $recommendationNote, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Recommendation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recommendationTarget = nil
                        recommendationNote = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        recommendedMemberIDs.insert(member.id)
                        recommendationTarget = nil
                        recommendationNote = ""
                    }
                }
            }
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined()
    }

    private func firstName(from fullName: String) -> String {
        fullName.components(separatedBy: " ").first ?? fullName
    }
}
