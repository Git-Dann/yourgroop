import SwiftUI

private enum MyGroopsSort: String, CaseIterable {
    case name
    case members

    var title: String {
        switch self {
        case .name:
            return "Name"
        case .members:
            return "Members"
        }
    }
}

struct MyGroopsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(AppRouter.self) private var router

    let groops: [Groop]

    @State private var searchText = ""
    @State private var sortMode: MyGroopsSort = .members
    @State private var selectedCategory: String = "All"
    @State private var isFilterSheetPresented = false

    private var categories: [String] {
        let unique = Set(groops.map(\.category))
        return ["All"] + unique.sorted()
    }

    private var visibleGroops: [Groop] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = groops.filter { groop in
            let matchesSearch: Bool
            if trimmed.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = groop.name.lowercased().contains(trimmed)
                    || groop.category.lowercased().contains(trimmed)
                    || groop.location.lowercased().contains(trimmed)
            }

            let matchesCategory = selectedCategory == "All" || groop.category == selectedCategory
            return matchesSearch && matchesCategory
        }

        switch sortMode {
        case .name:
            return filtered.sorted { $0.name < $1.name }
        case .members:
            return filtered.sorted { $0.memberCount > $1.memberCount }
        }
    }

    private var totalMembers: Int {
        groops.reduce(0) { $0 + $1.memberCount }
    }

    private var mostActiveGroop: Groop? {
        groops.max(by: { $0.memberCount < $1.memberCount })
    }

    private var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategory != "All"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroSection

                if appModel.isLoading && groops.isEmpty {
                    LoadingView(title: "Loading My Groops")
                        .frame(height: 160)
                } else if groops.isEmpty {
                    EmptyStateView(
                        systemImage: "person.3.sequence.fill",
                        title: "No Groops Yet",
                        message: "Join a local Groop from Discovery to see it here."
                    )
                    .padding(.top, 8)
                } else {
                    quickJumpSection
                    groopsSection
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
        .searchable(text: $searchText, prompt: "Search groops")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isFilterSheetPresented = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Open filters")
            }
        }
        .sheet(isPresented: $isFilterSheetPresented) {
            NavigationStack {
                Form {
                    Section("Sort by") {
                        Picker("Sort by", selection: $sortMode) {
                            ForEach(MyGroopsSort.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.inline)
                    }

                    Section("Category") {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                    }
                }
                .navigationTitle("Filter")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Reset") {
                            sortMode = .members
                            selectedCategory = "All"
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { isFilterSheetPresented = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .refreshable {
            await appModel.refreshAll()
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your communities")
                .font(.headline)

            Text("Stay on top of your groops, activity, and local members in one place.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                statPill(title: "Groops", value: "\(groops.count)", tint: .blue)
                statPill(title: "Members", value: "\(totalMembers)", tint: .indigo)

                if let mostActiveGroop {
                    statPill(title: "Top Groop", value: mostActiveGroop.name, tint: .teal)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(uiColor: .systemBlue).opacity(0.16), Color(uiColor: .systemTeal).opacity(0.16)],
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

    private var quickJumpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Jump")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(visibleGroops.prefix(4))) { groop in
                        NavigationLink(value: AppRoute.groopDetail(groop.id)) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(groop.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 4)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }

                                Text(groop.location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                HStack {
                                    Label("\(groop.memberCount)", systemImage: "person.2.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Text("Open")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.tint)
                                }
                            }
                            .frame(width: 172, alignment: .leading)
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 8)
            }
            .scrollClipDisabled()
        }
    }

    private var groopsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All My Groops")
                .font(.headline)

            if visibleGroops.isEmpty {
                Text("No matches for your current filters.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if hasActiveFilters {
                    Button("Reset filters") {
                        searchText = ""
                        selectedCategory = "All"
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                ForEach(visibleGroops) { groop in
                    NavigationLink(value: AppRoute.groopDetail(groop.id)) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 10) {
                                Text(groop.name)
                                    .font(.headline)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 4)
                            }

                            Text("\(groop.category) • \(groop.location)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                Label("\(groop.memberCount) members", systemImage: "person.2.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(groop.category)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Color(uiColor: .tertiarySystemFill), in: Capsule())

                                Text("Open")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.indigo, in: Capsule())
                            }
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Open Groop Chat", systemImage: "message.fill") {
                            router.navigate(to: .groopChat(groop.id, prefill: nil))
                        }
                        Button("View Members", systemImage: "person.3.fill") {
                            router.navigate(to: .groopMembers(groop.id))
                        }
                    }
                    .accessibilityIdentifier("myGroopRow_\(groop.id.uuidString)")
                    .accessibilityLabel("\(groop.name), \(groop.memberCount) members")
                }
            }
        }
    }

    private func statPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
