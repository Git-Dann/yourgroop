import SwiftUI

enum RootTab: Hashable {
    case home
    case myGroops
    case discovery
}

struct AppRootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(AppRouter.self) private var router
    @State private var selectedTab: RootTab = .home
    @State private var isProfilePresented = false
    
    private var selectedTabTitle: String {
        switch selectedTab {
        case .home:
            return "Home"
        case .myGroops:
            return "My Groops"
        case .discovery:
            return ""
        }
    }
    
    private var shouldHideNavigationBar: Bool {
        if !appModel.isSignedIn { return true }
        return selectedTab == .discovery && router.path.isEmpty
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            Group {
                if appModel.isSignedIn {
                    if appModel.isLoading && appModel.myGroops.isEmpty {
                        LoadingView(title: "Loading Your Groops")
                    } else {
                        TabView(selection: $selectedTab) {
                            HomeDashboardView(
                                onOpenMyGroops: { selectedTab = .myGroops },
                                onOpenDiscovery: { selectedTab = .discovery }
                            )
                                .tabItem {
                                    Label("Home", systemImage: "house.fill")
                                }
                                .tag(RootTab.home)

                            MyGroopsView(groops: appModel.myGroops)
                                .tabItem {
                                    Label("My Groops", systemImage: "person.3")
                                }
                                .tag(RootTab.myGroops)

                            DiscoveryView(groops: appModel.discoveryGroops)
                                .tabItem {
                                    Label("Discovery", systemImage: "location.magnifyingglass")
                                }
                                .tag(RootTab.discovery)
                        }
                        .tint(Color(uiColor: .systemTeal))
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
                    }
                } else {
                    SignInView()
                }
            }
            .navigationTitle(selectedTabTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(shouldHideNavigationBar ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                if appModel.isSignedIn, selectedTab != .discovery, router.path.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isProfilePresented = true
                        } label: {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title3.weight(.semibold))
                        }
                        .accessibilityLabel("Open Profile")
                    }
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
