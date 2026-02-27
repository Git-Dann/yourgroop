import SwiftUI

enum RootTab: Hashable {
    case home
    case myGroops
    case discovery
    case compose
}

struct AppRootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(AppRouter.self) private var router
    @State private var selectedTab: RootTab = .home
    @State private var lastNonDiscoveryTab: RootTab = .home
    @State private var isProfilePresented = false
    @State private var isComposeActionSheetPresented = false
    @State private var isComposeMessageSheetPresented = false
    @State private var isStartThreadSheetPresented = false
    @State private var composeGroopSearchText = ""
    @State private var composeTargets: [ComposeMessageTarget] = []
    
    private var selectedTabTitle: String {
        switch selectedTab {
        case .home:
            return ""
        case .myGroops:
            return "My Groops"
        case .discovery:
            return ""
        case .compose:
            return ""
        }
    }
    
    private var shouldHideNavigationBar: Bool {
        if !appModel.isSignedIn { return true }
        return (selectedTab == .discovery || selectedTab == .home) && router.path.isEmpty
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            rootContent
            .navigationTitle(selectedTabTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(shouldHideNavigationBar ? .hidden : .visible, for: .navigationBar)
            .onChange(of: selectedTab) { _, newValue in
                if newValue == .compose {
                    selectedTab = lastNonDiscoveryTab
                    isComposeActionSheetPresented = true
                    return
                }

                if newValue != .discovery {
                    lastNonDiscoveryTab = newValue
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .groopDetail(let groopId):
                    GroopDetailView(groopId: groopId, repository: appModel.repository)
                case .groopChat(let groopId, let prefill):
                    GroopChatView(groopId: groopId, repository: appModel.repository, prefillText: prefill)
                case .groopMembers(let groopId):
                    GroopMembersView(groopId: groopId, repository: appModel.repository)
                case .announcementDetail(let groopId, let announcementId):
                    AnnouncementDetailView(groopId: groopId, announcementId: announcementId, repository: appModel.repository)
                }
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if appModel.isSignedIn {
            if appModel.isLoading && appModel.myGroops.isEmpty {
                LoadingView(title: "Loading Your Groops")
            } else {
                mainTabs
            }
        } else {
            SignInView()
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: RootTab.home) {
                HomeDashboardView(
                    onOpenMyGroops: { selectedTab = .myGroops },
                    onOpenDiscovery: { selectedTab = .discovery },
                    onOpenProfile: { isProfilePresented = true }
                )
            }

            Tab("My Groops", systemImage: "person.3", value: RootTab.myGroops) {
                MyGroopsView(groops: appModel.myGroops)
            }

            Tab("Discovery", systemImage: "location.magnifyingglass", value: RootTab.discovery) {
                DiscoveryView(
                    groops: appModel.discoveryGroops,
                    isActive: selectedTab == .discovery,
                    onBack: { selectedTab = lastNonDiscoveryTab }
                )
            }

            Tab("+", systemImage: "plus", value: RootTab.compose, role: .search) {
                Color.clear
            }
        }
        .tint(Color(uiColor: .systemBlue))
        .sheet(isPresented: $isProfilePresented) {
            NavigationStack {
                ProfileHubView(
                    onOpenMyGroops: {
                        selectedTab = .myGroops
                    },
                    onOpenDiscovery: {
                        selectedTab = .discovery
                    }
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isComposeMessageSheetPresented) {
            NewMessageComposerView(targets: composeTargets) { target, message in
                Task { @MainActor in
                    _ = await appModel.repository.sendMessage(
                        groopId: target.groopId,
                        body: message,
                        senderName: appModel.session?.displayName ?? "Taylor",
                        isFromCurrentUser: true
                    )
                    try? await Task.sleep(nanoseconds: 140_000_000)
                    router.navigate(to: .groopChat(target.groopId, prefill: nil))
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isStartThreadSheetPresented) {
            startThreadSheet
        }
        .confirmationDialog(
            "Compose",
            isPresented: $isComposeActionSheetPresented,
            titleVisibility: .visible
        ) {
            Button("Compose Message") {
                Task {
                    await loadComposeTargets()
                    isComposeMessageSheetPresented = true
                }
            }
            Button("Start New Thread") {
                composeGroopSearchText = ""
                isStartThreadSheetPresented = true
            }
            Button("Broadcast") {
                if let groop = appModel.myGroops.first {
                    router.navigate(to: .groopChat(groop.id, prefill: "Broadcast: "))
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var startThreadSheet: some View {
        NavigationStack {
            List {
                ForEach(filteredComposeGroops) { groop in
                    Button {
                        isStartThreadSheetPresented = false
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 140_000_000)
                            router.navigate(to: .groopChat(groop.id, prefill: "Thread: "))
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(groop.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(groop.category) • \(groop.location)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Start New Thread")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $composeGroopSearchText, prompt: "Search groops")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        isStartThreadSheetPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var filteredComposeGroops: [Groop] {
        let query = composeGroopSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return appModel.myGroops }

        return appModel.myGroops.filter { groop in
            groop.name.lowercased().contains(query)
                || groop.category.lowercased().contains(query)
                || groop.location.lowercased().contains(query)
        }
    }

    private func loadComposeTargets() async {
        var targets: [ComposeMessageTarget] = []

        for groop in appModel.myGroops {
            let members = await appModel.repository.fetchMembers(for: groop.id)
            for member in members where !member.isHost {
                targets.append(
                    ComposeMessageTarget(
                        id: member.id,
                        groopId: groop.id,
                        groopName: groop.name,
                        memberName: member.name,
                        jobTitle: member.jobTitle
                    )
                )
            }
        }

        composeTargets = targets.sorted { lhs, rhs in
            if lhs.memberName == rhs.memberName {
                return lhs.groopName < rhs.groopName
            }
            return lhs.memberName < rhs.memberName
        }
    }
}

private struct ComposeMessageTarget: Identifiable {
    let id: UUID
    let groopId: UUID
    let groopName: String
    let memberName: String
    let jobTitle: String
}

private struct NewMessageComposerView: View {
    @Environment(\.dismiss) private var dismiss

    let targets: [ComposeMessageTarget]
    let onSend: (ComposeMessageTarget, String) -> Void

    @State private var selectedTarget: ComposeMessageTarget?
    @State private var draftMessage = ""
    @State private var isRecipientPickerPresented = false
    @State private var recipientSearchText = ""
    @State private var isFeatureMenuPresented = false

    private var filteredTargets: [ComposeMessageTarget] {
        let query = recipientSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return targets }

        return targets.filter { target in
            target.memberName.lowercased().contains(query)
                || target.groopName.lowercased().contains(query)
                || target.jobTitle.lowercased().contains(query)
        }
    }

    private var canSend: Bool {
        selectedTarget != nil && !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    isRecipientPickerPresented = true
                } label: {
                    HStack(spacing: 8) {
                        Text("To:")
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)

                        if let selectedTarget {
                            Text("\(selectedTarget.memberName), \(selectedTarget.groopName)")
                                .foregroundStyle(.blue)
                                .lineLimit(1)
                        } else {
                            Text("Choose member")
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .font(.body.weight(.regular))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.top, 10)

                Spacer(minLength: 0)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 10) {
                        Button {
                            isFeatureMenuPresented = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color(uiColor: .systemBlue))
                                .frame(width: 34, height: 34)
                                .background(.regularMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog(
                            "Message Features",
                            isPresented: $isFeatureMenuPresented,
                            titleVisibility: .visible
                        ) {
                            Button("Poll") { }
                            Button("Event") { }
                            Button("Question") { }
                            Button("Calendar") { }
                            Button("Cancel", role: .cancel) { }
                        }

                        TextField("iMessage", text: $draftMessage, axis: .vertical)
                            .lineLimit(1...4)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color(uiColor: .separator).opacity(0.2), lineWidth: 1)
                            )

                        Button {
                            guard let selectedTarget else { return }
                            let message = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !message.isEmpty else { return }
                            onSend(selectedTarget, message)
                            dismiss()
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(Color(uiColor: .systemBlue), in: Circle())
                        }
                        .disabled(!canSend)
                        .opacity(canSend ? 1 : 0.45)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(.bar)
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .background(Color(uiColor: .secondarySystemBackground), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $isRecipientPickerPresented) {
                NavigationStack {
                    List {
                        ForEach(filteredTargets) { target in
                            Button {
                                selectedTarget = target
                                isRecipientPickerPresented = false
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(target.memberName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("\(target.jobTitle) • \(target.groopName)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .navigationTitle("Select Member")
                    .navigationBarTitleDisplayMode(.inline)
                    .searchable(text: $recipientSearchText, prompt: "Search members")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") {
                                isRecipientPickerPresented = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct ProfileHubView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    let onOpenMyGroops: () -> Void
    let onOpenDiscovery: () -> Void

    @State private var isCreateGroopPresented = false
    @State private var isPreferencesPresented = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.teal)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(appModel.session?.displayName ?? "Your Profile")
                            .font(.headline)
                        Text("North West Builder")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Groops") {
                Button {
                    dismiss()
                    onOpenMyGroops()
                } label: {
                    HStack {
                        Text("Joined Groops")
                        Spacer()
                        Text("\(appModel.myGroops.count)")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open My Groops")

                Button {
                    dismiss()
                    onOpenDiscovery()
                } label: {
                    HStack {
                        Text("Nearby Discoveries")
                        Spacer()
                        Text("\(appModel.discoveryGroops.count)")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Discovery")
            }

            Section("Actions") {
                Button {
                    isCreateGroopPresented = true
                } label: {
                    Label("Create Groop", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)

                Button {
                    isPreferencesPresented = true
                } label: {
                    Label("Profile Preferences", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isCreateGroopPresented) {
            NavigationStack {
                CreateGroopView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isPreferencesPresented) {
            NavigationStack {
                ProfilePreferencesView()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct ProfilePreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pref_notifications") private var notificationsEnabled = true
    @AppStorage("pref_location_sharing") private var locationSharingEnabled = true
    @AppStorage("pref_show_job_title") private var showJobTitle = true

    var body: some View {
        Form {
            Section("Visibility") {
                Toggle("Show my job title to members", isOn: $showJobTitle)
                Toggle("Share approximate location", isOn: $locationSharingEnabled)
            }

            Section("Updates") {
                Toggle("Announcements and chat notifications", isOn: $notificationsEnabled)
            }
        }
        .navigationTitle("Profile Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }
}

private struct CreateGroopView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category = "Co-Working"
    @State private var location = "Campfield, Manchester"
    @State private var isSubmitting = false

    private let categories = ["Co-Working", "Fitness", "Books", "Games", "Outdoors", "Arts"]

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
    }

    var body: some View {
        Form {
            Section("Groop Details") {
                TextField("Groop name", text: $name)
                    .textInputAutocapitalization(.words)

                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { item in
                        Text(item).tag(item)
                    }
                }

                TextField("Location", text: $location)
                    .textInputAutocapitalization(.words)
            }

            Section {
                Button {
                    Task {
                        isSubmitting = true
                        await appModel.createGroop(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category,
                            location: location.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        isSubmitting = false
                        dismiss()
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Groop")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .navigationTitle("Create Groop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }
}
