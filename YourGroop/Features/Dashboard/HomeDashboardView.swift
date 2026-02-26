import SwiftUI

struct HomeDashboardView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(AppRouter.self) private var router

    let onOpenMyGroops: () -> Void
    let onOpenDiscovery: () -> Void

    @State private var latestUpdates: [DashboardUpdate] = []
    @State private var isLoadingUpdates = false
    @State private var selectedUpdateKind: DashboardUpdateKind = .all
    @State private var joiningGroopIDs: Set<UUID> = []

    private var myGroopIDs: [UUID] {
        appModel.myGroops.map(\.id)
    }

    private var filteredUpdates: [DashboardUpdate] {
        switch selectedUpdateKind {
        case .all:
            return latestUpdates
        case .announcements:
            return latestUpdates.filter { $0.kind == .announcements }
        case .activity:
            return latestUpdates.filter { $0.kind == .activity }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroSection

                HStack(spacing: 12) {
                    metricCard(
                        title: "My Groops",
                        value: "\(appModel.myGroops.count)",
                        symbol: "person.3.fill",
                        tint: Color(uiColor: .systemBlue),
                        action: onOpenMyGroops
                    )
                    metricCard(
                        title: "Local Discovers",
                        value: "\(appModel.discoveryGroops.count)",
                        symbol: "location.magnifyingglass",
                        tint: Color(uiColor: .systemGreen),
                        action: onOpenDiscovery
                    )
                }

                if appModel.myGroops.isEmpty {
                    EmptyStateView(
                        systemImage: "person.3.sequence.fill",
                        title: "No Joined Groops",
                        message: "Join from Discovery to start seeing local updates here."
                    )
                } else {
                    myGroopsSection
                    updatesSection
                }

                discoverySpotlightSection
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
        .task(id: myGroopIDs) {
            await loadLatestUpdates()
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back")
                .font(.headline)

            Text("Your North West groop's activity at a glance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Label("\(Date.now.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                Label("\(latestUpdates.count) updates", systemImage: "bolt.fill")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(uiColor: .systemTeal).opacity(0.2), Color(uiColor: .systemIndigo).opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        )
    }

    private var myGroopsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Your Groops", buttonTitle: "See all", action: onOpenMyGroops)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appModel.myGroops) { groop in
                        Button {
                            router.navigate(to: .groopDetail(groop.id))
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(groop.name)
                                    .font(.subheadline.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)

                                Text(groop.location)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                Label("\(groop.memberCount) members", systemImage: "person.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 190, alignment: .leading)
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Latest Updates")

            Picker("Update type", selection: $selectedUpdateKind) {
                ForEach(DashboardUpdateKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            if isLoadingUpdates {
                ProgressView("Loading updates")
                    .font(.subheadline)
            } else if filteredUpdates.isEmpty {
                Text("No updates for this filter yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(filteredUpdates.prefix(6))) { update in
                        updateRow(update)
                    }
                }
            }
        }
    }

    private func updateRow(_ update: DashboardUpdate) -> some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: iconName(for: update.kind))
                    .foregroundStyle(iconColor(for: update.kind))
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 4) {
                    Text(update.title)
                        .font(.subheadline.weight(.semibold))
                    Text(update.groopName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(update.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func iconName(for kind: DashboardUpdateKind) -> String {
        switch kind {
        case .announcements:
            return "megaphone.fill"
        case .activity, .all:
            return "bolt.fill"
        }
    }

    private func iconColor(for kind: DashboardUpdateKind) -> Color {
        switch kind {
        case .announcements:
            return .orange
        case .activity, .all:
            return .blue
        }
    }

    private var discoverySpotlightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Discovery Spotlight", buttonTitle: "Open Discovery", action: onOpenDiscovery)

            if appModel.discoveryGroops.isEmpty {
                Text("No nearby Groops available right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appModel.discoveryGroops.prefix(2)) { groop in
                    SurfaceCard {
                        Text(groop.name)
                            .font(.headline)
                        Text("\(groop.category) • \(groop.location)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("\(groop.memberCount) members")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                joiningGroopIDs.insert(groop.id)
                                Task {
                                    await appModel.joinGroop(id: groop.id)
                                    joiningGroopIDs.remove(groop.id)
                                }
                            } label: {
                                if joiningGroopIDs.contains(groop.id) {
                                    ProgressView()
                                } else {
                                    Text("Join")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(joiningGroopIDs.contains(groop.id))
                        }
                    }
                }
            }
        }
    }

    private func metricCard(title: String, value: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func sectionHeader(title: String, buttonTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .font(.subheadline.weight(.medium))
            }
        }
    }

    private func loadLatestUpdates() async {
        guard !appModel.myGroops.isEmpty else {
            latestUpdates = []
            return
        }

        isLoadingUpdates = true
        defer { isLoadingUpdates = false }

        var collected: [DashboardUpdate] = []

        for groop in appModel.myGroops {
            let announcements = await appModel.repository.fetchAnnouncements(for: groop.id)
            if let latestAnnouncement = announcements.first {
                collected.append(
                    DashboardUpdate(
                        id: latestAnnouncement.id,
                        groopName: groop.name,
                        title: latestAnnouncement.title,
                        createdAt: latestAnnouncement.createdAt,
                        kind: .announcements
                    )
                )
            }

            let feedItems = await appModel.repository.feedItems(for: groop.id)
            if let latestFeed = feedItems.first {
                collected.append(
                    DashboardUpdate(
                        id: latestFeed.id,
                        groopName: groop.name,
                        title: latestFeed.message,
                        createdAt: latestFeed.timestamp,
                        kind: .activity
                    )
                )
            }
        }

        latestUpdates = collected.sorted { $0.createdAt > $1.createdAt }
    }
}

private struct DashboardUpdate: Identifiable {
    let id: UUID
    let groopName: String
    let title: String
    let createdAt: Date
    let kind: DashboardUpdateKind
}

private enum DashboardUpdateKind: String, CaseIterable {
    case all
    case announcements
    case activity

    var title: String {
        switch self {
        case .all:
            return "All"
        case .announcements:
            return "Announcements"
        case .activity:
            return "Activity"
        }
    }
}
