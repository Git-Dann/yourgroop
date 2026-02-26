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

    let groops: [Groop]

    @State private var searchText = ""
    @State private var sortMode: MyGroopsSort = .members
    @State private var selectedCategory: String = "All"

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
                    sortAndFilterSection
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

    private var sortAndFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filter & Sort")
                .font(.headline)

            Picker("Sort groops", selection: $sortMode) {
                ForEach(MyGroopsSort.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == category ?
                                    AnyShapeStyle(Color(uiColor: .systemBlue).opacity(0.2)) :
                                    AnyShapeStyle(.regularMaterial),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var quickJumpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Jump")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(visibleGroops.prefix(4))) { groop in
                        NavigationLink(value: AppRoute.groopDetail(groop.id)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(groop.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Text(groop.location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 170, alignment: .leading)
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
            } else {
                ForEach(visibleGroops) { groop in
                    NavigationLink(value: AppRoute.groopDetail(groop.id)) {
                        SurfaceCard {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(groop.name)
                                        .font(.headline)
                                        .multilineTextAlignment(.leading)

                                    Text("\(groop.category) • \(groop.location)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Label("\(groop.memberCount) members", systemImage: "person.2.fill")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
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
