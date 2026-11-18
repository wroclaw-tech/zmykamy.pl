import SwiftUI

struct GlobeRotation: Equatable {
    var longitude: Double
    var latitude: Double

    static let initial = GlobeRotation(longitude: 15, latitude: 30)

    func dragged(by translation: CGSize) -> GlobeRotation {
        GlobeRotation(
            longitude: longitude - translation.width * 0.4,
            latitude: min(max(latitude + translation.height * 0.4, -70), 70)
        )
    }

    func centering(_ destination: InspirationDestination) -> GlobeRotation {
        var delta = (destination.longitude + 8 - longitude).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
        return GlobeRotation(
            longitude: longitude + delta + (delta < 0 ? -360 : 360),
            latitude: min(max(destination.latitude - 10, -60), 60)
        )
    }
}

struct GlobeProjection {
    let rotation: GlobeRotation
    let center: CGPoint
    let radius: CGFloat

    func project(longitude: Double, latitude: Double) -> (point: CGPoint, isVisible: Bool) {
        let phi = latitude * .pi / 180
        let lambda = (longitude - rotation.longitude) * .pi / 180
        let phi0 = rotation.latitude * .pi / 180
        let depth = sin(phi0) * sin(phi) + cos(phi0) * cos(phi) * cos(lambda)
        var x = cos(phi) * sin(lambda)
        var y = cos(phi0) * sin(phi) - sin(phi0) * cos(phi) * cos(lambda)
        if depth < 0 {
            let length = max(hypot(x, y), .ulpOfOne)
            x /= length
            y /= length
        }
        return (CGPoint(x: center.x + x * radius, y: center.y - y * radius), depth >= 0)
    }
}

struct InspirationGlobe: View, Animatable {
    var rotation: GlobeRotation
    let destinations: [InspirationDestination]
    let selected: InspirationDestination?
    @Environment(\.theme) private var theme

    private let diameter: CGFloat = 266

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(rotation.longitude, rotation.latitude) }
        set { rotation = GlobeRotation(longitude: newValue.first, latitude: newValue.second) }
    }

    private var projection: GlobeProjection {
        GlobeProjection(rotation: rotation, center: CGPoint(x: diameter / 2, y: diameter / 2), radius: diameter / 2)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(theme.accent)
                .frame(width: 290, height: 290)
                .blur(radius: 14)
                .opacity(0.18)
                .padding(.top, -6)
            Ellipse()
                .fill(.neutralInk)
                .frame(width: 180, height: 16)
                .blur(radius: 4)
                .opacity(0.12)
                .padding(.top, 278)
            Canvas(renderer: draw)
                .frame(width: diameter, height: diameter)
                .overlay(alignment: .topLeading) { label }
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 296, alignment: .top)
    }

    @ViewBuilder
    private var label: some View {
        if let selected {
            let projected = projection.project(longitude: selected.longitude, latitude: selected.latitude)
            if projected.isVisible {
                HStack(spacing: 5) {
                    Image(.locationOn)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(theme.accent)
                    Text(selected.name)
                        .typography(.subheadEmphasis)
                        .foregroundStyle(.neutralInk)
                }
                .padding(.leading, 9)
                .padding(.trailing, Spacing.s12)
                .padding(.vertical, 7)
                .background(.neutralWhite, in: .capsule)
                .shadow(color: .black.opacity(0.14), radius: 6, y: 4)
                .fixedSize()
                .position(x: projected.point.x, y: projected.point.y - 37)
            }
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let projection = projection
        let disc = Path(ellipseIn: CGRect(origin: .zero, size: size))
        context.fill(disc, with: .color(theme.accent))
        context.clip(to: disc)

        var land = context
        land.opacity = 0.16
        land.drawLayer { layer in
            for outline in GlobeLand.outlines {
                if let path = Self.area(outline, projection: projection) {
                    layer.fill(path, with: .color(.white))
                }
            }
        }

        var grid = Path()
        for longitude in stride(from: -180.0, to: 180, by: 30) {
            Self.line(stride(from: -90.0, through: 90, by: 3).map { (longitude, $0) }, projection: projection, into: &grid)
        }
        for latitude in stride(from: -60.0, through: 60, by: 30) {
            Self.line(stride(from: -180.0, through: 180, by: 4).map { ($0, latitude) }, projection: projection, into: &grid)
        }
        context.stroke(grid, with: .color(.white.opacity(0.22)), lineWidth: 1)
        context.stroke(disc, with: .color(.white.opacity(0.24)), lineWidth: 2)

        context.fill(disc, with: .radialGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0.32), location: 0),
                .init(color: .white.opacity(0), location: 0.45),
                .init(color: .black.opacity(0.28), location: 1),
            ]),
            center: CGPoint(x: size.width * 0.35, y: size.height * 0.3),
            startRadius: 0,
            endRadius: size.width * 0.667
        ))

        for destination in destinations where destination != selected {
            let projected = projection.project(longitude: destination.longitude, latitude: destination.latitude)
            guard projected.isVisible else { continue }
            context.fill(Self.circle(at: projected.point, radius: 3), with: .color(.white.opacity(0.8)))
        }

        if let selected {
            let projected = projection.project(longitude: selected.longitude, latitude: selected.latitude)
            if projected.isVisible {
                context.fill(Self.circle(at: projected.point, radius: 14), with: .color(.white.opacity(0.35)))
                let dot = Self.circle(at: projected.point, radius: 4.75)
                context.fill(dot, with: .color(.white))
                context.stroke(dot, with: .color(theme.accentStrong), lineWidth: 2.5)
            }
        }
    }

    private static func circle(at point: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }

    private static func line(_ points: [(Double, Double)], projection: GlobeProjection, into path: inout Path) {
        var isDrawing = false
        for (longitude, latitude) in points {
            let projected = projection.project(longitude: longitude, latitude: latitude)
            if !projected.isVisible {
                isDrawing = false
            } else if isDrawing {
                path.addLine(to: projected.point)
            } else {
                path.move(to: projected.point)
                isDrawing = true
            }
        }
    }

    private static func area(_ outline: [(Double, Double)], projection: GlobeProjection) -> Path? {
        var path = Path()
        var isVisible = false
        for (index, start) in outline.enumerated() {
            let end = outline[(index + 1) % outline.count]
            let steps = max(1, Int(max(abs(end.0 - start.0), abs(end.1 - start.1)) / 3))
            for step in 0..<steps {
                let t = Double(step) / Double(steps)
                let projected = projection.project(longitude: start.0 + (end.0 - start.0) * t, latitude: start.1 + (end.1 - start.1) * t)
                isVisible = isVisible || projected.isVisible
                if path.isEmpty {
                    path.move(to: projected.point)
                } else {
                    path.addLine(to: projected.point)
                }
            }
        }
        path.closeSubpath()
        return isVisible ? path : nil
    }
}

private enum GlobeLand {
    static let outlines: [[(Double, Double)]] = [
        [(-10, 36), (-6, 36), (-2, 36.7), (3, 42), (8, 44), (12, 44), (16, 38), (18.5, 40), (20, 39), (23, 36.5), (26, 38),
         (26, 40.5), (29, 41), (28, 43), (30, 45), (34, 44.5), (38, 47), (40, 44), (42, 42), (50, 45), (55, 50), (60, 55),
         (60, 68), (45, 68), (40, 66), (30, 70), (20, 70), (12, 66), (5, 62), (8, 58), (11, 59), (12, 56), (9, 55),
         (8, 54), (4, 52), (-2, 49), (-5, 48), (-1, 46), (-2, 43.5), (-9, 43.5)],
        [(-5, 50), (1, 51), (2, 53), (-2, 56), (-2, 58.5), (-5, 58.5), (-6, 56), (-3, 54), (-5, 52)],
        [(-10, 52), (-6, 52), (-6, 55), (-8, 55.3), (-10, 54)],
        [(-24, 64), (-22, 66), (-15, 66.5), (-13, 65), (-18, 63.5)],
        [(-17, 21), (-17, 15), (-12, 8), (-8, 4.5), (0, 5.5), (8, 4.5), (10, 2), (9, -2), (12, -6), (13, -12), (12, -18),
         (15, -27), (18, -34.5), (22, -34), (27, -33), (32, -28), (35, -24), (35, -18), (40, -15), (40, -10), (39, -5),
         (42, 0), (48, 5), (51, 11), (44, 11), (43, 13), (38, 18), (35, 24), (33, 29), (32, 31), (25, 32), (20, 31),
         (15, 32), (10, 33), (10, 37), (3, 37), (-6, 36), (-10, 30), (-13, 27)],
        [(44, -25), (47, -25), (50, -15), (49, -12), (44, -16)],
        [(60, 55), (60, 68), (70, 73), (80, 73), (100, 77), (115, 74), (130, 71), (140, 72), (160, 70), (180, 68),
         (180, 65), (170, 60), (163, 57), (156, 51), (155, 58), (142, 59), (135, 54), (141, 48), (135, 43), (130, 42),
         (127, 39), (129, 35), (126, 35), (126, 38), (121, 40), (122, 37), (119, 35), (122, 30), (120, 25), (115, 22),
         (110, 21), (108, 16), (109, 12), (106, 9), (103, 10), (100, 13), (100, 8), (103, 1.5), (98, 8), (98, 16),
         (94, 17), (92, 22), (88, 22), (86, 20), (80, 15), (80, 10), (77, 8), (73, 17), (72, 22), (67, 25), (62, 25),
         (57, 25), (56, 27), (52, 28), (48, 30), (50, 26), (55, 24), (56, 22), (59, 22), (55, 17), (52, 16), (45, 13),
         (43, 13), (39, 21), (35, 28), (34, 31), (35, 36), (36, 37), (28, 37), (26, 40.5), (29, 41), (28, 43), (30, 45),
         (34, 44.5), (38, 47), (40, 44), (42, 42), (50, 45), (55, 50)],
        [(130, 31), (132, 34), (136, 35), (140, 35), (141, 38), (142, 41), (141, 45), (145, 44), (143, 42), (140, 41),
         (140, 38), (136, 37), (133, 36), (130, 34)],
        [(95, 5.5), (98, 4), (104, -2), (106, -6), (102, -4), (96, 3)],
        [(105, -6), (114, -7), (114, -8.5), (106, -7)],
        [(109, 2), (111, -3), (116, -4), (119, 1), (117, 7), (113, 3)],
        [(79.8, 9.8), (81.8, 7.5), (80.6, 6), (79.8, 7)],
        [(-168, 66), (-156, 71), (-140, 70), (-125, 70), (-100, 68), (-82, 70), (-75, 62), (-65, 60), (-56, 52),
         (-60, 47), (-66, 44), (-70, 42), (-75, 38), (-76, 35), (-81, 31), (-80, 25), (-82, 27), (-84, 30), (-90, 29.5),
         (-97, 28), (-97, 22), (-92, 18.5), (-87, 21), (-88, 16), (-84, 11), (-79.5, 9), (-80, 7.5), (-83, 8.5),
         (-86, 12), (-92, 14.5), (-96, 16), (-105, 20), (-110, 24), (-112, 29), (-110, 23), (-115, 30), (-118, 34),
         (-121, 35), (-124, 40), (-124, 48), (-130, 54), (-136, 58), (-148, 60), (-152, 58), (-158, 57), (-165, 54),
         (-160, 59), (-165, 62)],
        [(-85, 22), (-80, 23), (-74, 20), (-78, 20), (-84, 21.8)],
        [(-74, 19.8), (-69, 19.5), (-68.4, 18.5), (-71, 17.8), (-74, 18.3)],
        [(-55, 60), (-43, 60), (-35, 66), (-22, 70), (-20, 76), (-20, 81), (-35, 83), (-60, 82), (-72, 78), (-66, 76),
         (-56, 74), (-52, 68)],
        [(-80, 9), (-77, 8), (-72, 12), (-62, 10.5), (-52, 5), (-50, 0), (-44, -2.5), (-35, -5), (-35, -9), (-39, -14),
         (-40, -22), (-48, -26), (-53, -34), (-58, -38), (-62, -39), (-65, -42), (-67, -46), (-69, -51), (-68, -55),
         (-72, -54), (-75, -50), (-74, -42), (-73, -36), (-71, -30), (-70, -18), (-76, -14), (-81, -6), (-80, -1),
         (-77, 4)],
        [(114, -22), (114, -34), (118, -35), (124, -33.5), (131, -31.5), (136, -35), (140, -38), (146, -39),
         (150, -37), (153, -32), (153, -25), (146, -19), (145, -15), (142, -11), (141, -17), (136, -15), (137, -12),
         (131, -11), (127, -14), (122, -17)],
        [(172, -34.5), (178, -38), (175, -41.5), (171, -44), (167, -46), (169, -43), (173, -41)],
    ]
}
