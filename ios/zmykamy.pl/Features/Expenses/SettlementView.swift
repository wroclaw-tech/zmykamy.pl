import SwiftUI

struct SettlementView: View {
    let trip: Trip
    let user: AuthUser

    @Environment(ExpensesStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var isShowingPayment = false
    @State private var isConfirmingPaid = false
    @State private var isWorking = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    var body: some View {
        Group {
            if let settlement = store.settlement(for: trip) {
                ScrollView {
                    VStack(spacing: Spacing.s16) {
                        heroCard(settlement)
                        progressCard(settlement)
                        transfersSection(settlement)
                    }
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.bottom, Spacing.s24)
                }
                .refreshable { try? await store.loadSettlement(trip) }
                .sheet(isPresented: $isShowingPayment) {
                    PayTransferSheet(trip: trip, transfers: settlement.transfers(from: user.id)) { transfer in
                        markPaid(transfer)
                    }
                }
                .confirmationDialog("Oznaczyć jako opłacone?", isPresented: $isConfirmingPaid, titleVisibility: .visible) {
                    ForEach(settlement.transfers(from: user.id)) { transfer in
                        Button("\(transfer.to.name) · \(MoneyFormat.precise(minorUnits: transfer.amount, currency: trip.currency))") {
                            markPaid(transfer)
                        }
                    }
                } message: {
                    Text("Oznacz przelew dopiero po jego wysłaniu.")
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background { theme.background.ignoresSafeArea() }
        .navigationTitle("Rozliczenia")
        .navigationSubtitle(trip.name)
        .task(id: trip.id) { try? await store.loadSettlement(trip) }
        .alert("Coś poszło nie tak", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func heroCard(_ settlement: Settlement) -> some View {
        let outgoing = settlement.transfers(from: user.id)
        let incoming = settlement.transfers(to: user.id)
        let expenses = store.expenses(for: trip) ?? []
        let summary = ExpenseSummary(expenses: expenses, members: trip.members, userID: user.id)
        let paidByMe = summary.payers.first { $0.userId == user.id }?.amount ?? 0
        let counterparts = outgoing.isEmpty ? incoming.map(\.from) : outgoing.map(\.to)
        let total = (outgoing.isEmpty ? incoming : outgoing).reduce(0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: Spacing.s16) {
            HStack {
                Text(outgoing.isEmpty ? (incoming.isEmpty ? "Twoje saldo" : "Do odebrania") : "Do zapłaty")
                    .typography(.calloutRegular)
                    .foregroundStyle(.neutralWhite.opacity(0.85))
                Spacer()
                if let first = counterparts.first {
                    HStack(spacing: Spacing.s6) {
                        PersonAvatar(userID: first.userId, name: first.name, size: 20)
                        Text(counterparts.count == 1 ? first.name : PolishPlural.people(counterparts.count))
                            .typography(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(.neutralWhite)
                    }
                    .padding(.leading, Spacing.s4)
                    .padding(.trailing, Spacing.s12)
                    .frame(height: 28)
                    .background(.neutralWhite.opacity(0.18), in: .capsule)
                }
            }
            Text(total == 0 ? "Rozliczone" : MoneyFormat.precise(minorUnits: total, currency: trip.currency))
                .typography(Typography(size: 44, weight: .heavy, tracking: -1.5))
                .foregroundStyle(.neutralWhite)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(spacing: Spacing.s8) {
                heroTile(title: "Twoja część", value: summary.myShare)
                heroTile(title: "Zapłacone przez Ciebie", value: paidByMe)
            }
            if !outgoing.isEmpty {
                HStack(spacing: Spacing.s8) {
                    Button { isShowingPayment = true } label: {
                        heroButtonLabel("Zapłać", image: .payments)
                            .typography(.headline)
                            .foregroundStyle(theme.accentStrong)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(.neutralWhite, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    Button { isConfirmingPaid = true } label: {
                        heroButtonLabel("Oznacz jako opłacone", image: .checkCircle)
                            .typography(.subheadEmphasis)
                            .foregroundStyle(.neutralWhite)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(.neutralWhite.opacity(0.18), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                }
            }
        }
        .padding(Spacing.s20)
        .background(
            LinearGradient(colors: [theme.accent, theme.accentStrong], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: Radius.xl)
        )
        .shadow(color: theme.accent.opacity(0.3), radius: 16, y: 8)
    }

    private func heroButtonLabel(_ title: String, image: ImageResource) -> some View {
        HStack(spacing: Spacing.s6) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
            Text(title)
        }
    }

    private func heroTile(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .typography(.captionRegular)
                .foregroundStyle(.neutralWhite.opacity(0.8))
                .lineLimit(1)
            Text(MoneyFormat.precise(minorUnits: value, currency: trip.currency))
                .typography(.headline)
                .foregroundStyle(.neutralWhite)
        }
        .padding(Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite.opacity(0.16), in: .rect(cornerRadius: Radius.sm))
    }

    private func progressCard(_ settlement: Settlement) -> some View {
        let total = settlement.transferCount
        let paid = settlement.payments.count
        return VStack(alignment: .leading, spacing: Spacing.s12) {
            HStack {
                Text("Postęp rozliczenia")
                    .typography(.headline)
                    .foregroundStyle(.neutralInk)
                Spacer()
                if total > 0 {
                    Text("\(paid) z \(total) opłacone")
                        .typography(.subheadEmphasis)
                        .foregroundStyle(.statusSuccess)
                }
            }
            if total > 0 {
                HStack(spacing: Spacing.s4) {
                    ForEach(0..<total, id: \.self) { index in
                        Capsule()
                            .fill(index < paid ? AnyShapeStyle(.statusSuccess) : AnyShapeStyle(.alphaFill))
                            .frame(height: 6)
                    }
                }
            }
            Text(progressDescription(settlement))
                .typography(.footnote)
                .foregroundStyle(.neutralGray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.lg))
    }

    private func progressDescription(_ settlement: Settlement) -> String {
        let total = settlement.transferCount
        if total == 0 {
            return "Nikt nikomu nic nie jest winien."
        }
        let transfers = PolishPlural.form(total, one: "przelew", few: "przelewy", many: "przelewów")
        if settlement.naiveTransferCount > total {
            let naive = PolishPlural.form(settlement.naiveTransferCount, one: "przelewu", few: "przelewów", many: "przelewów")
            return "Saldo grupy zamyka \(total) \(transfers) zamiast \(settlement.naiveTransferCount) \(naive) przy rozliczaniu każdego wydatku osobno."
        }
        return "Saldo grupy zamyka \(total) \(transfers)."
    }

    @ViewBuilder
    private func transfersSection(_ settlement: Settlement) -> some View {
        if settlement.transferCount > 0 {
            VStack(spacing: Spacing.s8) {
                HStack {
                    Text("PRZELEWY W GRUPIE")
                    Spacer()
                    Text("\(settlement.transferCount)")
                }
                .typography(.sectionLabel)
                .foregroundStyle(.neutralGray)
                .padding(.horizontal, Spacing.s6)

                ListCard {
                    ForEach(settlement.transfers.sorted { isMine($0) && !isMine($1) }) { transfer in
                        TransferRow(
                            from: transfer.from,
                            to: transfer.to,
                            amount: transfer.amount,
                            currency: trip.currency,
                            userID: user.id,
                            isPaid: false
                        )
                        .contextMenu {
                            if canRecord(from: transfer.from, to: transfer.to) {
                                Button("Oznacz jako opłacone", image: .checkCircle) { markPaid(transfer) }
                            }
                        }
                    }
                    ForEach(settlement.payments) { payment in
                        TransferRow(
                            from: payment.from,
                            to: payment.to,
                            amount: payment.amount,
                            currency: trip.currency,
                            userID: user.id,
                            isPaid: true
                        )
                        .contextMenu {
                            if canRecord(from: payment.from, to: payment.to) {
                                Button("Cofnij oznaczenie", role: .destructive) { undo(payment) }
                            }
                        }
                    }
                }
                Text("Przytrzymaj przelew, żeby oznaczyć go jako opłacony albo cofnąć oznaczenie.")
                    .typography(.footnote)
                    .foregroundStyle(.neutralGray)
                    .padding(.horizontal, Spacing.s6)
            }
        }
    }

    private func isMine(_ transfer: SettlementTransfer) -> Bool {
        transfer.from.userId == user.id || transfer.to.userId == user.id
    }

    private func canRecord(from: ExpensePerson, to: ExpensePerson) -> Bool {
        trip.isOrganizer || from.userId == user.id || to.userId == user.id
    }

    private func markPaid(_ transfer: SettlementTransfer) {
        perform { () throws(APIError) in try await store.markPaid(transfer, in: trip) }
    }

    private func undo(_ payment: SettlementPayment) {
        perform { () throws(APIError) in try await store.undo(payment, in: trip) }
    }

    private func perform(_ action: @escaping () async throws(APIError) -> Void) {
        isWorking = true
        Task {
            do throws(APIError) {
                try await action()
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
            isWorking = false
        }
    }
}

struct TransferRow: View {
    let from: ExpensePerson
    let to: ExpensePerson
    let amount: Int
    let currency: String
    let userID: String
    let isPaid: Bool
    @Environment(\.theme) private var theme

    private var isOutgoing: Bool { from.userId == userID }
    private var isIncoming: Bool { to.userId == userID }

    private var subtitle: String {
        if isPaid { return "Rozliczone" }
        if isOutgoing { return "Twój przelew" }
        if isIncoming { return "Do Ciebie" }
        return "Do wykonania"
    }

    var body: some View {
        HStack(spacing: Spacing.s12) {
            HStack(spacing: Spacing.s4) {
                PersonAvatar(userID: from.userId, name: from.name, isViewer: isOutgoing, size: 30)
                Image(.arrowForward)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(.neutralGray2)
                PersonAvatar(userID: to.userId, name: to.name, isViewer: isIncoming, size: 30)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(isOutgoing ? "Ty" : from.name) → \(isIncoming ? "Ty" : to.name)")
                    .typography(.bodyEmphasis)
                    .foregroundStyle(.neutralInk)
                    .lineLimit(1)
                Text(subtitle)
                    .typography(.captionRegular)
                    .foregroundStyle(!isPaid && (isOutgoing || isIncoming) ? theme.accentStrong : .neutralGray)
            }
            Spacer(minLength: Spacing.s8)
            VStack(alignment: .trailing, spacing: Spacing.s4) {
                Text(MoneyFormat.precise(minorUnits: amount, currency: currency))
                    .typography(.bodyEmphasis)
                    .foregroundStyle(isPaid ? .neutralGray2 : .neutralInk)
                    .strikethrough(isPaid)
                statusPill
            }
        }
        .padding(.horizontal, Spacing.s14)
        .padding(.vertical, Spacing.s12)
        .background(!isPaid && isOutgoing ? theme.accentTint : .clear)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var statusPill: some View {
        HStack(spacing: 3) {
            Image(isPaid ? .checkCircle : .schedule)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
            Text(isPaid ? "Opłacone" : "Oczekuje")
                .typography(.captionEmphasis)
        }
        .foregroundStyle(isPaid ? .statusSuccess : .neutralGray)
        .padding(.horizontal, Spacing.s8)
        .frame(height: 22)
        .background(isPaid ? AnyShapeStyle(.statusSuccessTint) : AnyShapeStyle(.alphaFill), in: .capsule)
    }
}
