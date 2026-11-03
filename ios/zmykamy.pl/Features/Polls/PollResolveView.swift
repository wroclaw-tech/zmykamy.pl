import SwiftUI

struct PollResolveView: View {
    let trip: Trip
    let user: AuthUser
    let poll: Poll

    @Environment(PollsStore.self) private var polls
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var winnerID: String
    @State private var addsToPlan = false
    @State private var planDate: LocalDate
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    init(trip: Trip, user: AuthUser, poll: Poll) {
        self.trip = trip
        self.user = user
        self.poll = poll
        _winnerID = State(initialValue: (poll.leadingOption ?? poll.options.first)?.id ?? "")
        _planDate = State(initialValue: trip.startDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s12) {
                    FormCard(title: "Zwycięzca") {
                        ForEach(poll.options) { option in
                            Button { winnerID = option.id } label: {
                                FormFieldRow {
                                    Image(winnerID == option.id ? .checkCircle : .radioButtonUnchecked)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .foregroundStyle(winnerID == option.id ? theme.accent : .neutralGray3)
                                    Text(option.name)
                                        .typography(.bodyRegular)
                                        .foregroundStyle(.neutralInk)
                                    Spacer(minLength: Spacing.s8)
                                    Text("\(option.voteCount)")
                                        .typography(.bodyEmphasis)
                                        .foregroundStyle(.neutralGray)
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    FormCard(title: "Plan") {
                        FormFieldRow {
                            Toggle("Przypisz do dnia", isOn: $addsToPlan.animation())
                                .typography(.bodyRegular)
                        }
                        if addsToPlan {
                            FormFieldRow {
                                Picker("Dzień", selection: $planDate) {
                                    ForEach(trip.days(calendar: user.calendar), id: \.self) { day in
                                        Text(PlanDateFormat.weekdayDayMonth(day, calendar: user.calendar)).tag(day)
                                    }
                                }
                                .typography(.bodyRegular)
                            }
                        }
                    }
                    PrimaryButton(title: "Rozstrzygnij", isEnabled: !isSaving, action: save)
                        .padding(.top, Spacing.s12)
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.s20)
                .padding(.bottom, Spacing.s24)
            }
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle(poll.question)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .alert("Nie udało się rozstrzygnąć", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .tint(theme.accent)
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        let request = PollResolveRequest(optionId: winnerID, planDate: addsToPlan ? planDate : nil)
        isSaving = true
        Task {
            defer { isSaving = false }
            do throws(APIError) {
                try await polls.resolve(poll, with: request, in: trip)
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
                return
            }
            dismiss()
        }
    }
}
