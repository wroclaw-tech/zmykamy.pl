import SwiftUI

struct ListCard<Content: View>: View {
    var separatorInset: CGFloat = 0
    var cornerRadius: CGFloat = Radius.xl
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(.neutralInk2.opacity(0.12))
                            .frame(height: 0.5)
                            .padding(.leading, separatorInset)
                    }
                    row
                }
            }
        }
        .background(.neutralWhite, in: .rect(cornerRadius: cornerRadius))
    }
}
