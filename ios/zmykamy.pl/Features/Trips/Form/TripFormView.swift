import PhotosUI
import SwiftUI

/// Creates a trip, or edits one when `trip` is given.
struct TripFormView: View {
    let user: AuthUser
    var trip: Trip?
    var onSaved: (Trip) -> Void = { _ in }

    @Environment(TripsStore.self) private var trips
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var name: String
    @State private var destination: TripDestination?
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var currency: String
    @State private var photoItem: PhotosPickerItem?
    @State private var newCover: UIImage?
    @State private var removesCover = false
    @State private var isSearchingDestination = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var isShowingError = false
    @State private var isShowingCoverError = false
    @State private var savedTrip: Trip?
    @State private var wizardTrip: Trip?

    init(user: AuthUser, trip: Trip? = nil, destination: TripDestination? = nil, onSaved: @escaping (Trip) -> Void = { _ in }) {
        self.user = user
        self.trip = trip
        self.onSaved = onSaved
        let today = Calendar.current.startOfDay(for: .now)
        _name = State(initialValue: trip?.name ?? destination?.name ?? "")
        _destination = State(initialValue: trip?.destination ?? destination)
        _startDate = State(initialValue: trip?.startDate.date() ?? today)
        _endDate = State(initialValue: trip?.endDate.date() ?? today)
        _currency = State(initialValue: trip?.currency ?? user.defaultCurrency ?? "PLN")
    }

    private var calendar: Calendar {
        user.calendar
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isSaving
    }

    private var hasCoverPhoto: Bool {
        newCover != nil || (trip?.coverUrl != nil && !removesCover)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s12) {
                    placeCard
                    datesCard
                    coverCard
                    currencyCard
                    saveButton
                        .padding(.top, Spacing.s12)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.s20)
                .padding(.bottom, Spacing.s24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle(trip == nil ? "Nowy wyjazd" : "Edytuj wyjazd")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm, action: save)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isSearchingDestination) {
                DestinationSearchView { selected in
                    if trimmedName.isEmpty || trimmedName == destination?.name {
                        name = selected.name
                    }
                    destination = selected
                }
            }
            .onChange(of: photoItem) { _, item in
                Task { await loadCover(from: item) }
            }
            .onChange(of: startDate) { _, start in
                if endDate < start { endDate = start }
            }
            .alert("Nie udało się zapisać", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .navigationDestination(isPresented: Binding(get: { wizardTrip != nil }, set: { if !$0 { wizardTrip = nil } })) {
                if let wizardTrip {
                    PlanWizardView(trip: wizardTrip, user: user, onFinish: { dismiss() })
                }
            }
            .alert("Nie udało się zapisać okładki", isPresented: $isShowingCoverError) {
                Button("OK", role: .cancel) { finishSaving() }
            } message: {
                Text("Wyjazd jest zapisany. Okładkę możesz dodać później w edycji wyjazdu.")
            }
        }
        .environment(\.calendar, calendar)
        .environment(\.locale, calendar.locale ?? .current)
        .tint(theme.accent)
        .interactiveDismissDisabled(isSaving)
    }

    private var placeCard: some View {
        FormCard(title: "Dokąd?") {
            Button { isSearchingDestination = true } label: {
                FormFieldRow {
                    Text(destination.map { [$0.name, $0.country].compactMap(\.self).joined(separator: ", ") } ?? "Wybierz miejsce")
                        .typography(.bodyRegular)
                        .foregroundStyle(destination == nil ? AnyShapeStyle(.neutralGray) : AnyShapeStyle(.neutralInk))
                        .lineLimit(1)
                    Spacer()
                    if destination == nil {
                        Image(.chevronRight)
                            .foregroundStyle(.neutralGray)
                    }
                }
            }
            .buttonStyle(.plain)
            .overlay(alignment: .trailing) {
                if destination != nil {
                    Button("Usuń miejsce", image: .close) { destination = nil }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.neutralGray)
                        .padding(.trailing, Spacing.s14)
                }
            }

            FormFieldRow {
                TextField("Nazwa wyjazdu", text: $name, prompt: Text("np. Sylwek w Zakopanem"))
                    .typography(.bodyRegular)
                    .foregroundStyle(.neutralInk)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
            }
        }
    }

    private var datesCard: some View {
        FormCard(title: "Kiedy?") {
            Text(TripDateFormat.summary(LocalDate(startDate, calendar: calendar), LocalDate(endDate, calendar: calendar), calendar: calendar))
                .typography(Typography(size: 13, weight: .semibold))
                .foregroundStyle(theme.accentStrong)
        } content: {
            FormFieldRow {
                DatePicker("Od", selection: $startDate, displayedComponents: .date)
                    .typography(.bodyRegular)
            }
            FormFieldRow {
                DatePicker("Do", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .typography(.bodyRegular)
            }
        }
    }

    private var coverCard: some View {
        FormCard(title: "Okładka") {
            if hasCoverPhoto {
                Button("Usuń") {
                    newCover = nil
                    photoItem = nil
                    removesCover = true
                }
                .typography(.subheadEmphasis)
                .foregroundStyle(theme.accentStrong)
            }
        } content: {
            HStack(spacing: Spacing.s12) {
                coverPreview
                    .frame(width: 46, height: 46)
                    .clipShape(.rect(cornerRadius: Radius.sm))
                PhotosPicker(selection: $photoItem, matching: .images) {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .strokeBorder(.neutralGray3, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(width: 46, height: 46)
                        .overlay {
                            Image(.addPhotoAlternate)
                                .foregroundStyle(.neutralGray)
                        }
                }
                .accessibilityLabel("Wybierz zdjęcie okładki")
            }
        }
    }

    @ViewBuilder
    private var coverPreview: some View {
        if let newCover {
            Image(uiImage: newCover)
                .resizable()
                .scaledToFill()
        } else {
            TripCover(url: removesCover ? nil : trip?.coverUrl)
        }
    }

    private var currencyCard: some View {
        FormCard(title: "Waluta") {
            NavigationLink {
                CurrencyPickerView(selection: $currency)
            } label: {
                FormFieldRow {
                    Text(currency)
                        .typography(.bodyEmphasis)
                        .foregroundStyle(.neutralInk)
                    Text(Currency.name(currency))
                        .typography(.bodyRegular)
                        .foregroundStyle(.neutralInk2)
                        .lineLimit(1)
                    Spacer()
                    Image(.chevronRight)
                        .foregroundStyle(.neutralGray)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: Spacing.s6) {
                Text(trip == nil ? "Utwórz wyjazd" : "Zapisz zmiany")
                    .typography(.headline)
                if trip == nil {
                    Image(.flightTakeoff)
                }
            }
            .foregroundStyle(.neutralWhite)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(theme.accent.opacity(canSave ? 1 : 0.4), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private func loadCover(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        newCover = image
        removesCover = false
    }

    private func save() {
        let request = TripRequest(
            name: trimmedName,
            destination: destination,
            startDate: LocalDate(startDate, calendar: calendar),
            endDate: LocalDate(endDate, calendar: calendar),
            currency: currency
        )
        isSaving = true
        Task {
            defer { isSaving = false }
            let saved: Trip
            do throws(APIError) {
                if let trip {
                    try await trips.update(trip, with: request)
                    saved = trip
                } else {
                    saved = try await trips.create(request)
                }
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
                return
            }
            onSaved(saved)
            savedTrip = saved

            if newCover != nil || removesCover {
                do throws(APIError) {
                    try await trips.setCover(of: saved, to: newCover)
                } catch {
                    isShowingCoverError = true
                    return
                }
            }
            finishSaving()
        }
    }

    /// A new trip continues into the plan step; editing just closes the form.
    private func finishSaving() {
        if trip == nil, let savedTrip {
            wizardTrip = savedTrip
        } else {
            dismiss()
        }
    }
}
