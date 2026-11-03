import SwiftUI

struct IconBadge<Foreground: ShapeStyle, Background: ShapeStyle>: View {
    let image: ImageResource
    let foreground: Foreground
    let background: Background

    var body: some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .foregroundStyle(foreground)
            .frame(width: 34, height: 34)
            .background(background, in: .rect(cornerRadius: Radius.xs))
    }
}
