import SwiftUI
import MapKit
import CoreLocation

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
    var isActive: Bool = true
    var onBack: (() -> Void)? = nil

    @Namespace private var mapScope
    @StateObject private var locationManager = DiscoveryLocationManager()

    @State private var searchText = ""
    @State private var joiningGroopIDs: Set<UUID> = []
    @State private var isDiscoverySheetPresented = true
    @State private var selectedDetent: PresentationDetent = .medium

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
            let matchesSearch: Bool
            if query.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = groop.name.lowercased().contains(query)
                    || groop.category.lowercased().contains(query)
                    || groop.location.lowercased().contains(query)
            }

            return matchesSearch
        }

        return filtered.sorted { $0.memberCount > $1.memberCount }
    }

    private var featuredGroops: [Groop] {
        Array(filteredGroops.prefix(3))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            mapBackdrop
            mapFloatingControls
        }
        .task {
            locationManager.requestPermission()
        }
        .sheet(isPresented: $isDiscoverySheetPresented) {
            discoverySheet
                .interactiveDismissDisabled(true)
                .presentationDetents([.fraction(0.26), .medium, .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(26)
                .presentationBackgroundInteraction(.enabled)
        }
        .onAppear {
            if isActive {
                isDiscoverySheetPresented = true
            }
        }
        .onChange(of: isActive) { _, active in
            isDiscoverySheetPresented = active
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

    private var mapFloatingControls: some View {
        VStack(spacing: 10) {
            MapCompass(scope: mapScope)
            MapUserLocationButton(scope: mapScope)
                .buttonBorderShape(.circle)
                .onTapGesture {
                    centerOnUserIfAvailable()
                }
        }
        .padding(.trailing, 14)
        .padding(.top, 110)
    }

    private var discoverySheet: some View {
        NavigationStack {
            List {
                if filteredGroops.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Local Matches",
                            systemImage: "globe",
                            description: Text("Try another search term.")
                        )
                    }
                } else {
                    Section("Featured Nearby") {
                        featuredRow
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color(uiColor: .systemGroupedBackground))
                    }

                    Section("All Results") {
                        resultsRows(limit: 6)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search nearby Groops"
            )
            .navigationTitle("Discovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if onBack != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onBack?()
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                        .accessibilityLabel("Back")
                        .tint(.primary)
                    }
                }
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
                        .background(
                            Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color(uiColor: .separator).opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func resultsRows(limit: Int) -> some View {
        ForEach(Array(filteredGroops.prefix(limit))) { groop in
            let meta = meta(for: groop)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(groop.name)
                        .font(.headline)
                    Text("\(groop.category) • \(groop.location)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Label(meta.distance, systemImage: "figure.walk")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if meta.isActiveNow {
                            Label("Active now", systemImage: "bolt.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
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
                .disabled(joiningGroopIDs.contains(groop.id))
                .accessibilityLabel("Join \(groop.name)")
            }
            .padding(.vertical, 4)
        }
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
        selectedDetent = .medium
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

}
