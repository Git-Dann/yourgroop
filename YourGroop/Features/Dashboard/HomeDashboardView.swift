import SwiftUI

struct HomeDashboardView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(AppRouter.self) private var router

    let onOpenMyGroops: () -> Void
    let onOpenDiscovery: () -> Void
    let onOpenProfile: () -> Void

    @State private var latestUpdates: [DashboardUpdate] = []
    @State private var chatThreads: [DashboardChatThread] = []
    @State private var inboxSummary = DashboardInboxSummary()
    @State private var isLoadingUpdates = false
    @State private var selectedUpdateKind: DashboardUpdateKind = .all
    @State private var joiningGroopIDs: Set<UUID> = []

    private var myGroopIDs: [UUID] {
        appModel.myGroops.map(\.id)
    }
    
    private var activeTodayCount: Int {
        latestUpdates.filter { Calendar.current.isDateInToday($0.createdAt) }.count
    }
    
    private var nearCampfieldCount: Int {
        appModel.discoveryGroops.filter { $0.location.localizedCaseInsensitiveContains("Campfield") }.count
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
        GeometryReader { geo in
            VStack(spacing: 0) {
                topSummaryCard(topInset: geo.safeAreaInsets.top)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if appModel.myGroops.isEmpty {
                            EmptyStateView(
                                systemImage: "person.3.sequence.fill",
                                title: "No Joined Groops",
                                message: "Join from Discovery to start seeing local updates here."
                            )
                        } else {
                            inboxSection
                            continueChatSection
                            myGroopsSection
                            updatesSection
                        }

                        discoverySpotlightSection
                    }
                    .padding(.top, 16)
                    .padding(.horizontal)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(
                LinearGradient(
                    colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .task(id: myGroopIDs) {
            await loadLatestUpdates()
        }
    }

    private func topSummaryCard(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome back")
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack(spacing: 14) {
                        Label("\(Date.now.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                        Label("\(latestUpdates.count) updates", systemImage: "bolt.fill")
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Button(action: onOpenProfile) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(4)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text("Your North West groop's activity at a glance")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.84))
                .padding(.top, 14)

            HStack(spacing: 10) {
                metricCard(
                    title: "My Groops",
                    value: "\(appModel.myGroops.count)",
                    symbol: "person.3.fill",
                    tint: Color(uiColor: .systemOrange),
                    subtitle: activeTodayCount == 1 ? "1 active today" : "\(activeTodayCount) active today",
                    action: onOpenMyGroops
                )
                metricCard(
                    title: "Local Discovers",
                    value: "\(appModel.discoveryGroops.count)",
                    symbol: "location.magnifyingglass",
                    tint: Color(uiColor: .systemGreen),
                    subtitle: nearCampfieldCount == 0
                        ? "Explore nearby now"
                        : (nearCampfieldCount == 1 ? "1 near Campfield" : "\(nearCampfieldCount) near Campfield"),
                    action: onOpenDiscovery
                )
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, topInset + 12)
        .padding(.bottom, 16)
        .background(
            Color(red: 0.157, green: 0.180, blue: 0.537),
            in: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 26, bottomTrailingRadius: 26, topTrailingRadius: 0, style: .continuous)
        )
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 26, bottomTrailingRadius: 26, topTrailingRadius: 0, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    private var myGroopsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Your Groops", buttonTitle: "See all", action: onOpenMyGroops)

            GeometryReader { proxy in
                let availableWidth = proxy.size.width
                let cardWidth = max(236, availableWidth * 0.78)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(appModel.myGroops) { groop in
                            Button {
                                router.navigate(to: .groopDetail(groop.id))
                            } label: {
                                myGroopCarouselCard(groop: groop, width: cardWidth)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 2)
                    .padding(.trailing, 12)
                }
                .scrollClipDisabled()
            }
            .frame(height: 170)
        }
    }

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Inbox")

            HStack(spacing: 8) {
                inboxBadge(
                    title: "Unread",
                    value: inboxSummary.unread,
                    tint: .blue,
                    icon: "message.badge.fill"
                )
                inboxBadge(
                    title: "Mentions",
                    value: inboxSummary.mentions,
                    tint: .purple,
                    icon: "at"
                )
                inboxBadge(
                    title: "Pinned",
                    value: inboxSummary.pinned,
                    tint: .green,
                    icon: "pin.fill"
                )
            }
        }
    }

    private func inboxBadge(title: String, value: Int, tint: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)

            Text("\(value)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 76, alignment: .topLeading)
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private var continueChatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Continue Chat",
                buttonTitle: "Open inbox",
                action: {
                    if let firstThread = chatThreads.first {
                        router.navigate(to: .groopChat(firstThread.groopId, prefill: nil))
                    }
                }
            )

            if chatThreads.isEmpty {
                SurfaceCard {
                    Text("No active threads yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(chatThreads.prefix(3)) { thread in
                        continueChatRow(thread)
                    }
                }
            }
        }
    }

    private func continueChatRow(_ thread: DashboardChatThread) -> some View {
        Button {
            router.navigate(to: .groopChat(thread.groopId, prefill: nil))
        } label: {
            SurfaceCard {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "message.fill")
                        .foregroundStyle(.blue)
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(thread.groopName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if thread.mentionsYou {
                                Text("@you")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.purple)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.purple.opacity(0.14), in: Capsule())
                            } else if thread.isUnread {
                                Text("Unread")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.blue.opacity(0.14), in: Capsule())
                            }
                        }

                        Text("\(thread.senderName): \(thread.preview)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(thread.waitingLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("Reply")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func myGroopCarouselCard(groop: Groop, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            myGroopCardHeader(groop: groop)
            myGroopCardLocation(groop: groop)
            myGroopCardMeta(groop: groop)
            Divider()
            myGroopCardFooter(groop: groop)
        }
        .frame(width: width, alignment: .leading)
        .padding(14)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.22), lineWidth: 1)
        )
    }

    private func myGroopCardHeader(groop: Groop) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                Text(groop.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }

            Text("Join \(groop.memberCount) members in \(groop.category.lowercased()) meetups around \(groop.location).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func myGroopCardLocation(groop: Groop) -> some View {
        Label(groop.location, systemImage: "mappin.and.ellipse")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary.opacity(0.8))
            .lineLimit(1)
    }

    private func myGroopCardMeta(groop: Groop) -> some View {
        HStack(spacing: 8) {
            chip(text: groop.category, tint: .blue)
            chip(text: "Local", tint: .purple)
            Spacer(minLength: 0)
        }
    }

    private func chip(text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private func myGroopCardFooter(groop: Groop) -> some View {
        HStack(spacing: 8) {
            Label("\(groop.memberCount) members", systemImage: "person.2.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text("Open")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.indigo, in: Capsule())
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Latest Updates",
                buttonTitle: isLoadingUpdates ? "Refreshing..." : "Refresh",
                action: {
                    guard !isLoadingUpdates else { return }
                    Task { await loadLatestUpdates() }
                }
            )

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
        Button {
            openUpdate(update)
        } label: {
            SurfaceCard {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: iconName(for: update))
                        .foregroundStyle(iconColor(for: update))
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(update.title)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Text("\(update.groopName) • \(update.sourceTitle)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(update.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(update.callToActionTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func openUpdate(_ update: DashboardUpdate) {
        switch update.destination {
        case .announcement(let announcementId):
            router.navigate(to: .announcementDetail(groopId: update.groopId, announcementId: announcementId))
        case .chat:
            router.navigate(to: .groopChat(update.groopId, prefill: nil))
        case .groopDetail:
            router.navigate(to: .groopDetail(update.groopId))
        }
    }

    private func iconName(for update: DashboardUpdate) -> String {
        switch update.source {
        case .announcement:
            return "megaphone.fill"
        case .message:
            return "message.fill"
        case .feed:
            return "bolt.fill"
        }
    }

    private func iconColor(for update: DashboardUpdate) -> Color {
        switch update.source {
        case .announcement:
            return .orange
        case .message:
            return .green
        case .feed:
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(appModel.discoveryGroops.prefix(4)) { groop in
                            discoverySpotlightCard(groop)
                        }
                    }
                    .padding(.trailing, 12)
                }
            }
        }
    }

    private func discoverySpotlightCard(_ groop: Groop) -> some View {
        let imageName = discoverySpotlightImage(for: groop)

        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        discoverySpotlightFallback(for: groop)
                    }
                }
                .frame(height: 116)
                .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.50), .black.opacity(0.08), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )

                Text(groop.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.25), in: Capsule())
                    .padding(10)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(groop.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(groop.location)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(groop.memberCount)", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if joiningGroopIDs.contains(groop.id) {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button(groop.isJoined ? "Open" : "Join") {
                            if groop.isJoined {
                                router.navigate(to: .groopDetail(groop.id))
                            } else {
                                joiningGroopIDs.insert(groop.id)
                                Task {
                                    await appModel.joinGroop(id: groop.id)
                                    joiningGroopIDs.remove(groop.id)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 238, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            router.navigate(to: .groopDetail(groop.id))
        }
        .accessibilityAddTraits(.isButton)
    }

    private func discoverySpotlightImageName(for groop: Groop) -> String? {
        switch groop.name {
        case "Campfield Co-Working Circle":
            return "DiscoveryCampfield"
        case "Northern Runners MCR":
            return "DiscoveryRunners"
        case "Ancoats Book Circle":
            return "DiscoveryBooks"
        case "Chorlton Board Game Nights":
            return "DiscoveryGames"
        case "Salford Quays Creatives":
            return "DiscoveryArts"
        case "Peak District Weekend Hikers":
            return "DiscoveryOutdoors"
        default:
            return nil
        }
    }

    private func discoverySpotlightFallback(for groop: Groop) -> some View {
        let style: (gradient: [Color], symbol: String)

        switch groop.name {
        case "Campfield Co-Working Circle":
            style = ([Color.teal.opacity(0.7), Color.blue.opacity(0.65)], "building.2.fill")
        case "Peak District Weekend Hikers":
            style = ([Color.green.opacity(0.7), Color.mint.opacity(0.65)], "mountain.2.fill")
        case "Northern Runners MCR":
            style = ([Color.green.opacity(0.7), Color.teal.opacity(0.7)], "figure.run")
        case "Ancoats Book Circle":
            style = ([Color.indigo.opacity(0.7), Color.blue.opacity(0.65)], "book.closed.fill")
        case "Chorlton Board Game Nights":
            style = ([Color.orange.opacity(0.7), Color.pink.opacity(0.6)], "gamecontroller.fill")
        case "Salford Quays Creatives":
            style = ([Color.purple.opacity(0.7), Color.mint.opacity(0.65)], "paintpalette.fill")
        default:
            style = ([Color.cyan.opacity(0.7), Color.indigo.opacity(0.6)], "sparkles")
        }

        return ZStack {
            LinearGradient(colors: style.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: style.symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func discoverySpotlightImage(for groop: Groop) -> String? {
        discoverySpotlightImageName(for: groop)
    }

    private func metricCard(title: String, value: String, symbol: String, tint: Color, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Label(title, systemImage: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint.opacity(0.95))
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 82, alignment: .topLeading)
            .padding(10)
            .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
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
            chatThreads = []
            inboxSummary = DashboardInboxSummary()
            return
        }

        isLoadingUpdates = true
        defer { isLoadingUpdates = false }

        var collected: [DashboardUpdate] = []
        var threadCandidates: [DashboardChatThread] = []
        let mentionToken = appModel.session?.displayName.lowercased() ?? "taylor"
        var unreadCount = 0
        var mentionCount = 0

        for groop in appModel.myGroops {
            async let announcementsTask = appModel.repository.fetchAnnouncements(for: groop.id)
            async let feedTask = appModel.repository.feedItems(for: groop.id)
            async let messagesTask = appModel.repository.fetchMessages(for: groop.id)

            let (announcements, feedItems, messages) = await (announcementsTask, feedTask, messagesTask)

            for announcement in announcements.prefix(2) {
                collected.append(
                    DashboardUpdate(
                        id: announcement.id,
                        groopId: groop.id,
                        groopName: groop.name,
                        title: announcement.title,
                        createdAt: announcement.createdAt,
                        kind: .announcements,
                        source: .announcement,
                        destination: .announcement(announcement.id)
                    )
                )
            }

            for feed in feedItems.prefix(2) {
                collected.append(
                    DashboardUpdate(
                        id: feed.id,
                        groopId: groop.id,
                        groopName: groop.name,
                        title: feed.message,
                        createdAt: feed.timestamp,
                        kind: .activity,
                        source: .feed,
                        destination: .groopDetail
                    )
                )
            }

            let sortedMessages = messages.sorted { $0.createdAt < $1.createdAt }

            unreadCount += sortedMessages.filter { !$0.isFromCurrentUser }.count
            mentionCount += sortedMessages.filter { message in
                !message.isFromCurrentUser && containsMention(message.body, sessionNameToken: mentionToken)
            }.count

            if let latestMessage = sortedMessages.last {
                collected.append(
                    DashboardUpdate(
                        id: latestMessage.id,
                        groopId: groop.id,
                        groopName: groop.name,
                        title: "\(latestMessage.senderName): \(latestMessage.body)",
                        createdAt: latestMessage.createdAt,
                        kind: .activity,
                        source: .message,
                        destination: .chat
                    )
                )

                threadCandidates.append(
                    DashboardChatThread(
                        groopId: groop.id,
                        groopName: groop.name,
                        senderName: latestMessage.senderName,
                        preview: latestMessage.body,
                        createdAt: latestMessage.createdAt,
                        isUnread: !latestMessage.isFromCurrentUser,
                        mentionsYou: containsMention(latestMessage.body, sessionNameToken: mentionToken) && !latestMessage.isFromCurrentUser
                    )
                )
            }
        }

        latestUpdates = collected.sorted { $0.createdAt > $1.createdAt }
        chatThreads = threadCandidates.sorted { $0.createdAt > $1.createdAt }
        inboxSummary = DashboardInboxSummary(
            unread: unreadCount,
            mentions: mentionCount,
            pinned: min(threadCandidates.count, 2)
        )
    }

    private func containsMention(_ body: String, sessionNameToken: String) -> Bool {
        let lower = body.lowercased()
        return lower.contains("@") || lower.contains(sessionNameToken)
    }
}

private struct DashboardInboxSummary {
    var unread: Int = 0
    var mentions: Int = 0
    var pinned: Int = 0
}

private struct DashboardChatThread: Identifiable {
    var id: UUID { groopId }
    let groopId: UUID
    let groopName: String
    let senderName: String
    let preview: String
    let createdAt: Date
    let isUnread: Bool
    let mentionsYou: Bool

    var waitingLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: createdAt, relativeTo: .now)
        return "Waiting \(relative)"
    }
}

private struct DashboardUpdate: Identifiable {
    let id: UUID
    let groopId: UUID
    let groopName: String
    let title: String
    let createdAt: Date
    let kind: DashboardUpdateKind
    let source: DashboardUpdateSource
    let destination: DashboardUpdateDestination

    var sourceTitle: String {
        switch source {
        case .announcement:
            return "Announcement"
        case .feed:
            return "Activity"
        case .message:
            return "Groop Chat"
        }
    }

    var callToActionTitle: String {
        switch destination {
        case .announcement:
            return "Open"
        case .groopDetail:
            return "View"
        case .chat:
            return "Reply"
        }
    }
}

private enum DashboardUpdateSource {
    case announcement
    case feed
    case message
}

private enum DashboardUpdateDestination {
    case announcement(UUID)
    case groopDetail
    case chat
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
