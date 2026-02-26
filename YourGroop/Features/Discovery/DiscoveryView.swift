import SwiftUI
import MapKit
import CoreLocation

private enum DiscoveryCategory: String, CaseIterable {
    case all = "All"
    case coworking = "Co-Working"
    case fitness = "Fitness"
    case books = "Books"
    case games = "Games"
    case outdoors = "Outdoors"
    case arts = "Arts"
}

private enum DiscoveryMode: String, CaseIterable {
    case map = "Map"
    case list = "List"
}

private enum DiscoverySheetState {
    case peek
    case medium
    case full
}

private struct DiscoveryMeta {
    let distance: String
    let isActiveNow: Bool
}

final class DiscoveryLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
}

struct DiscoveryView: View {
    @Environment(AppModel.self) private var appModel

    let groops: [Groop]

    @Namespace private var mapScope
    @StateObject private var locationManager = DiscoveryLocationManager()

    @State private var searchText = ""
    @State private var selectedCategory: DiscoveryCategory = .all
    @State private var joiningGroopIDs: Set<UUID> = []
    @State private var mode: DiscoveryMode = .map

    @State private var sheetState: DiscoverySheetState = .medium
    @State private var dragTranslation: CGFloat = 0

    @State private var selectedGroopID: UUID?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 53.4808, longitude: -2.2426),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    private var filteredGroops: [Groop] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = groops.filter { groop in
            let matchesCategory = selectedCategory == .all || groop.category == selectedCategory.rawValue

            let matchesSearch: Bool
            if query.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = groop.name.lowercased().contains(query)
                    || groop.category.lowercased().contains(query)
                    || groop.location.lowercased().contains(query)
            }

            return matchesCategory && matchesSearch
        }

        return filtered.sorted { $0.memberCount > $1.memberCount }
    }

    private var featuredGroops: [Groop] {
        Array(filteredGroops.prefix(3))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                mapBackdrop

                draggableSheet(geo: geo)
                mapFloatingControls(geo: geo)
            }
            .task {
                locationManager.requestPermission()
            }
        }
    }

    private var mapBackdrop: some View {
        Map(position: $cameraPosition, selection: $selectedGroopID, scope: mapScope) {
            ForEach(filteredGroops) { groop in
                if let coordinate = coordinate(for: groop) {
                    Annotation(groop.name, coordinate: coordinate) {
                        VStack(spacing: 2) {
                            Image(systemName: selectedGroopID == groop.id ? "mappin.circle.fill" : "mappin.circle")
                                .font(.title3)
                                .foregroundStyle(selectedGroopID == groop.id ? .pink : .teal)
                            Text(groop.name)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                    .tag(groop.id)
                }
            }

            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea()
    }

    private func mapFloatingControls(geo: GeometryProxy) -> some View {
        VStack(spacing: 10) {
            MapCompass(scope: mapScope)
            MapUserLocationButton(scope: mapScope)
                .buttonBorderShape(.circle)
                .onTapGesture {
                    centerOnUserIfAvailable()
                }
        }
        .position(x: geo.size.width - 28, y: controlsYPosition(geo: geo))
    }

    private func draggableSheet(geo: GeometryProxy) -> some View {
        let heights = sheetHeights(totalHeight: geo.size.height)
        let maxHeight = heights.full
        let currentHeight = height(for: sheetState, heights: heights)
        let minOffset: CGFloat = 0
        let maxOffset: CGFloat = maxHeight - heights.peek
        let baseOffset = maxHeight - currentHeight
        let offset = (baseOffset + dragTranslation).clamped(to: minOffset...maxOffset)

        return VStack(spacing: 0) {
            sheetGrabber(heights: heights, maxHeight: maxHeight)
            sheetContent
        }
        .frame(height: maxHeight, alignment: .top)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .offset(y: offset)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: sheetState)
    }

    private func sheetGrabber(heights: (peek: CGFloat, medium: CGFloat, full: CGFloat), maxHeight: CGFloat) -> some View {
        let minOffset: CGFloat = 0
        let maxOffset: CGFloat = maxHeight - heights.peek

        return VStack(spacing: 8) {
            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 38, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    dragTranslation = value.translation.height
                }
                .onEnded { value in
                    let current = height(for: sheetState, heights: heights)
                    let rawOffset = (maxHeight - current + value.translation.height).clamped(to: minOffset...maxOffset)
                    let resultingHeight = maxHeight - rawOffset

                    let candidates: [DiscoverySheetState: CGFloat] = [
                        .peek: heights.peek,
                        .medium: heights.medium,
                        .full: heights.full
                    ]

                    if let nearest = candidates.min(by: {
                        abs($0.value - resultingHeight) < abs($1.value - resultingHeight)
                    })?.key {
                        sheetState = nearest
                    }

                    dragTranslation = 0
                }
        )
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            modeToggle
            searchRow
            categoryRow

            if mode == .map {
                mapModeContent
            } else {
                listModeContent
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 16)
    }

    private var modeToggle: some View {
        Picker("View", selection: $mode) {
            ForEach(DiscoveryMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search nearby Groops", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DiscoveryCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.rawValue)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory == category
                                    ? AnyShapeStyle(Color.white.opacity(0.28))
                                    : AnyShapeStyle(.thinMaterial),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var mapModeContent: some View {
        Group {
            if filteredGroops.isEmpty {
                EmptyStateView(
                    systemImage: "globe",
                    title: "No Local Matches",
                    message: "Try another category or search term."
                )
            } else {
                sectionTitle("Featured Nearby")
                featuredRow

                sectionTitle("All Results")
                resultsList(limit: 6)
            }
        }
    }

    private var listModeContent: some View {
        Group {
            if filteredGroops.isEmpty {
                EmptyStateView(
                    systemImage: "list.bullet",
                    title: "No Results",
                    message: "Try broadening your filters."
                )
            } else {
                sectionTitle("All Results")
                resultsList(limit: filteredGroops.count)
            }
        }
    }

    private var featuredRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(featuredGroops) { groop in
                    let meta = meta(for: groop)

                    Button {
                        focusOnGroop(groop)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(groop.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)

                            Text(groop.location)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 6) {
                                chip(text: meta.distance, icon: "figure.walk")
                                if meta.isActiveNow {
                                    chip(text: "Active now", icon: "bolt.fill", tint: .green)
                                }
                            }
                        }
                        .frame(width: 188, alignment: .leading)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func resultsList(limit: Int) -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(filteredGroops.prefix(limit))) { groop in
                    let meta = meta(for: groop)

                    SurfaceCard {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(groop.name)
                                    .font(.headline)
                                Text("\(groop.category) • \(groop.location)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 6) {
                                    chip(text: meta.distance, icon: "figure.walk")
                                    if meta.isActiveNow {
                                        chip(text: "Active now", icon: "bolt.fill", tint: .green)
                                    }
                                }

                                Text("\(groop.memberCount) members")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

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
                                        .frame(width: 58)
                                } else {
                                    Text("Join")
                                        .frame(width: 58)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(joiningGroopIDs.contains(groop.id))
                            .accessibilityLabel("Join \(groop.name)")
                        }
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.leading, 2)
    }

    private func chip(text: String, icon: String, tint: Color = .secondary) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(tint)
            .background(.thinMaterial, in: Capsule())
    }

    private func coordinate(for groop: Groop) -> CLLocationCoordinate2D? {
        switch groop.location {
        case "Campfield, Manchester":
            return CLLocationCoordinate2D(latitude: 53.4765, longitude: -2.2541)
        case "Manchester City Centre":
            return CLLocationCoordinate2D(latitude: 53.4808, longitude: -2.2426)
        case "Ancoats, Manchester":
            return CLLocationCoordinate2D(latitude: 53.4852, longitude: -2.2290)
        case "Chorlton-cum-Hardy":
            return CLLocationCoordinate2D(latitude: 53.4434, longitude: -2.2775)
        case "Salford Quays":
            return CLLocationCoordinate2D(latitude: 53.4729, longitude: -2.2965)
        case "Stockport":
            return CLLocationCoordinate2D(latitude: 53.4106, longitude: -2.1575)
        default:
            return CLLocationCoordinate2D(latitude: 53.4808, longitude: -2.2426)
        }
    }

    private func focusOnGroop(_ groop: Groop) {
        guard let coordinate = coordinate(for: groop) else { return }
        selectedGroopID = groop.id
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        )
        sheetState = .medium
    }

    private func centerOnUserIfAvailable() {
        guard let location = locationManager.currentLocation else { return }

        cameraPosition = .region(
            MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )
    }

    private func meta(for groop: Groop) -> DiscoveryMeta {
        switch groop.name {
        case "Campfield Co-Working Circle":
            return DiscoveryMeta(distance: "0.3 mi", isActiveNow: true)
        case "Chorlton Board Game Nights":
            return DiscoveryMeta(distance: "1.8 mi", isActiveNow: false)
        case "Salford Quays Creatives":
            return DiscoveryMeta(distance: "2.1 mi", isActiveNow: true)
        case "Peak District Weekend Hikers":
            return DiscoveryMeta(distance: "4.6 mi", isActiveNow: false)
        default:
            return DiscoveryMeta(distance: "1.2 mi", isActiveNow: false)
        }
    }

    private func sheetHeights(totalHeight: CGFloat) -> (peek: CGFloat, medium: CGFloat, full: CGFloat) {
        let peek = max(220, totalHeight * 0.30)
        let medium = max(360, totalHeight * 0.58)
        let full = max(460, totalHeight * 0.86)
        return (peek, medium, full)
    }

    private func height(for state: DiscoverySheetState, heights: (peek: CGFloat, medium: CGFloat, full: CGFloat)) -> CGFloat {
        switch state {
        case .peek:
            return heights.peek
        case .medium:
            return heights.medium
        case .full:
            return heights.full
        }
    }

    private func controlsYPosition(geo: GeometryProxy) -> CGFloat {
        let heights = sheetHeights(totalHeight: geo.size.height)
        let maxHeight = heights.full
        let currentHeight = height(for: sheetState, heights: heights)
        let maxOffset = maxHeight - heights.peek
        let baseOffset = maxHeight - currentHeight
        let offset = (baseOffset + dragTranslation).clamped(to: 0...maxOffset)
        let sheetTop = geo.size.height - maxHeight + offset
        let preferredY = sheetTop - 74
        let topLimit = geo.safeAreaInsets.top + 72
        return max(topLimit, preferredY)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
