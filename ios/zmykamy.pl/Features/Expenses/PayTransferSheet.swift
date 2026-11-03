import SwiftUI
import UIKit

struct PayTransferSheet: View {
    let trip: Trip
    let transfers: [SettlementTransfer]
    let onMarkPaid: (SettlementTransfer) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var copied: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s16) {
                    ForEach(transfers) { transfer in
                        transferCard(transfer)
                    }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.s16)
            }
            .background { theme.background.ignoresSafeArea() }
            .navigationTitle("Zapłać")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(theme.accent)
    }

    private func transferCard(_ transfer: SettlementTransfer) -> some View {
        let amount = MoneyFormat.precise(minorUnits: transfer.amount, currency: trip.currency)
        return VStack(alignment: .leading, spacing: Spacing.s12) {
            HStack(spacing: Spacing.s12) {
                PersonAvatar(userID: transfer.to.userId, name: transfer.to.name, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(transfer.to.name)
                        .typography(.headline)
                        .foregroundStyle(.neutralInk)
                    Text(amount)
                        .typography(.title3)
                        .foregroundStyle(theme.accentStrong)
                }
                Spacer()
            }
            ListCard {
                copyRow(label: "Kwota", value: amount, copyValue: amountForCopy(transfer.amount))
                if let blik = transfer.paymentDetails?.blikPhone {
                    copyRow(label: "Telefon do BLIK", value: FieldFormat.phone(blik), copyValue: blik)
                }
                if let iban = transfer.paymentDetails?.iban {
                    copyRow(label: "Numer konta", value: FieldFormat.iban(iban), copyValue: iban, isMonospaced: true)
                }
                copyRow(label: "Tytuł", value: trip.name, copyValue: trip.name)
            }
            if transfer.paymentDetails == nil {
                Text("\(transfer.to.name) nie ma jeszcze danych do przelewu. Poproś o uzupełnienie BLIK albo numeru konta w profilu.")
                    .typography(.footnote)
                    .foregroundStyle(.neutralGray)
            }
            PrimaryButton(title: "Oznacz jako opłacone") {
                onMarkPaid(transfer)
                dismiss()
            }
        }
        .padding(Spacing.s16)
        .background(.neutralWhite, in: .rect(cornerRadius: Radius.xl))
    }

    private func amountForCopy(_ minorUnits: Int) -> String {
        String(format: "%d,%02d", minorUnits / 100, minorUnits % 100)
    }

    private func copyRow(label: String, value: String, copyValue: String, isMonospaced: Bool = false) -> some View {
        Button {
            UIPasteboard.general.string = copyValue
            copied = label
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .typography(.captionRegular)
                        .foregroundStyle(.neutralGray)
                    Text(value)
                        .typography(.bodyRegular)
                        .monospaced(isMonospaced)
                        .foregroundStyle(.neutralInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                Image(copied == label ? .check : .contentCopy)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(theme.accentStrong)
            }
            .padding(.horizontal, Spacing.s14)
            .padding(.vertical, Spacing.s12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Kopiuje do schowka")
    }
}
