import MapKit
import SwiftUI

@Observable
private final class DestinationCompleter: NSObject {
    var query = "" {
        didSet { completer.queryFragment = query }
    }
    private(set) var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    init(near center: CLLocationCoordinate2D?) {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        if let center {
            completer.region = MKCoordinateRegion(center: center, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        }
        completer.delegate = self
    }
}

extension DestinationCompleter: @preconcurrency MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

/// Searches Apple Maps for a place; also picks plan point locations.
struct DestinationSearchView: View {
    let title: String
    let prompt: String
    let onSelect: (TripDestination) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var completer: DestinationCompleter

    /// `center` biases results towards places around it, such as the trip destination.
    init(
        title: String = "Dokąd?",
        prompt: String = "Lizbona, Zakopane…",
        near center: CLLocationCoordinate2D? = nil,
        onSelect: @escaping (TripDestination) -> Void
    ) {
        self.title = title
        self.prompt = prompt
        self.onSelect = onSelect
        _completer = State(initialValue: DestinationCompleter(near: center))
    }

    var body: some View {
        NavigationStack {
            List(completer.results, id: \.self) { completion in
                Button {
                    Task { await select(completion) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(completion.title)
                            .typography(.bodyEmphasis)
                            .foregroundStyle(.neutralInk)
                        if !completion.subtitle.isEmpty {
                            Text(completion.subtitle)
                                .typography(.subheadRegular)
                                .foregroundStyle(.neutralGray)
                        }
                    }
                }
            }
            .overlay {
                if completer.results.isEmpty {
                    ContentUnavailableView("Wpisz miasto albo miejsce", image: "language")
                }
            }
            .searchable(text: $completer.query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(prompt))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .tint(theme.accent)
    }

    /// Looks up the coordinates; the place is still usable by name when the lookup fails.
    private func select(_ completion: MKLocalSearchCompletion) async {
        let item = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start().mapItems.first
        let coordinate = item?.location.coordinate
        onSelect(TripDestination(
            name: completion.title,
            country: completion.subtitle.isEmpty ? nil : completion.subtitle,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude
        ))
        dismiss()
    }
}

#Preview {
    DestinationSearchView { _ in }
}
