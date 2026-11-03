import SwiftUI

struct GalleryMosaic<Item: Identifiable, Tile: View>: View {
    let items: [Item]
    var spacing: CGFloat = 2
    @ViewBuilder let tile: (Item, CGSize) -> Tile

    private enum Block: Identifiable {
        case feature(Item, Item, Item)
        case row([Item])

        var id: Item.ID {
            switch self {
            case .feature(let first, _, _): first.id
            case .row(let items): items[0].id
            }
        }
    }

    private var blocks: [Block] {
        var blocks: [Block] = []
        var index = 0
        while index < items.count {
            let remaining = items.count - index
            if remaining >= 3 && blocks.count.isMultiple(of: 2) {
                blocks.append(.feature(items[index], items[index + 1], items[index + 2]))
                index += 3
            } else {
                let end = min(index + 3, items.count)
                blocks.append(.row(Array(items[index..<end])))
                index = end
            }
        }
        return blocks
    }

    var body: some View {
        GeometryReader { proxy in
            let small = ((proxy.size.width - spacing * 2) / 3).rounded(.down)
            let large = small * 2 + spacing
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(blocks) { block in
                    switch block {
                    case .feature(let first, let second, let third):
                        HStack(spacing: spacing) {
                            tile(first, CGSize(width: large, height: large))
                            VStack(spacing: spacing) {
                                tile(second, CGSize(width: small, height: small))
                                tile(third, CGSize(width: small, height: small))
                            }
                        }
                    case .row(let row):
                        HStack(spacing: spacing) {
                            ForEach(row) { item in
                                tile(item, CGSize(width: small, height: small))
                            }
                        }
                    }
                }
            }
        }
        .frame(height: height)
    }

    private var height: CGFloat {
        let width = UIScreen.main.bounds.width
        let small = ((width - spacing * 2) / 3).rounded(.down)
        return blocks.reduce(0) { total, block in
            switch block {
            case .feature: total + small * 2 + spacing
            case .row: total + small
            }
        } + spacing * CGFloat(max(blocks.count - 1, 0))
    }
}

struct MediaTile: View {
    let item: MediaItem
    let size: CGSize
    let viewerID: String
    @Environment(\.theme) private var theme

    var body: some View {
        AsyncImage(url: item.thumbnailUrl) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Rectangle().fill(.alphaFill)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            if let uploader = item.uploadedBy {
                Circle()
                    .fill(uploader.userId == viewerID ? theme.accent : AvatarColor.color(for: uploader.userId))
                    .overlay { Circle().strokeBorder(.neutralWhite, lineWidth: 1.5) }
                    .frame(width: 10, height: 10)
                    .padding(Spacing.s8)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let duration = item.durationText {
                HStack(spacing: 2) {
                    Image(.playArrow)
                        .resizable()
                        .frame(width: 12, height: 12)
                    Text(duration)
                        .typography(.captionEmphasis)
                        .monospacedDigit()
                }
                .foregroundStyle(.neutralWhite)
                .padding(.horizontal, Spacing.s8)
                .frame(height: 22)
                .background(.black.opacity(0.45), in: .capsule)
                .padding(Spacing.s6)
            }
        }
        .contentShape(.rect)
        .accessibilityElement()
        .accessibilityLabel(item.kind == .video ? "Film" : "Zdjęcie")
        .accessibilityAddTraits(.isButton)
    }
}

struct UploadTile: View {
    let upload: GalleryStore.Upload
    let size: CGSize

    var body: some View {
        Group {
            if let preview = upload.preview {
                Image(uiImage: preview).resizable().scaledToFill()
            } else {
                Rectangle().fill(.alphaFill)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay {
            ZStack {
                Rectangle().fill(.black.opacity(0.35))
                if upload.isFailed {
                    Image(.refresh)
                        .resizable()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(.neutralWhite)
                } else {
                    ProgressView().tint(.neutralWhite)
                }
            }
        }
        .accessibilityLabel(upload.isFailed ? "Nie udało się wysłać, dotknij, aby ponowić" : "Wysyłanie")
    }
}
