import SwiftUI

struct IconBadge<Foreground: ShapeStyle, Background: ShapeStyle>: View {
    let image: ImageResource
    let foreground: Foreground
    let background: Background
    var size: CGFloat = 34
    var iconSize: CGFloat = 20
    var cornerRadius: CGFloat = Radius.xs

    var body: some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: .rect(cornerRadius: cornerRadius))
    }
}
