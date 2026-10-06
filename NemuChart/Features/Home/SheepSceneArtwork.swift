import SwiftUI

/// The same little world is used on Home and in the collection previews.
/// Collectibles are drawn as parts of the world rather than floating SF Symbols.
struct SheepSceneArtwork: View {
    let sheepAssetName: String
    var backgroundID: String? = nil
    var effectID: String? = nil
    var accessoryIDs: Set<String> = []
    var animate: Bool = false
    var fadeIntoStatus: Bool = false
    var nightMode: Bool = false
    @State private var floating = false

    private var isNight: Bool { nightMode || backgroundID == "stars" || effectID == "moonlight" }

    private var skyColors: [Color] {
        if isNight && backgroundID != "stars" {
            return [Color(red: 0.15, green: 0.27, blue: 0.52), Color(red: 0.47, green: 0.54, blue: 0.75)]
        }
        switch backgroundID {
        case "morning": return [Color(red: 0.61, green: 0.80, blue: 0.96), Color(red: 1, green: 0.88, blue: 0.70)]
        case "stars": return [Color(red: 0.11, green: 0.22, blue: 0.48), Color(red: 0.43, green: 0.49, blue: 0.73)]
        case "sunset": return [Color(red: 0.48, green: 0.55, blue: 0.84), Color(red: 1, green: 0.72, blue: 0.62)]
        case "garden": return [Color(red: 0.57, green: 0.79, blue: 0.91), Color(red: 0.94, green: 0.91, blue: 0.73)]
        default: return [Color(red: 0.62, green: 0.80, blue: 0.96), Color(red: 0.86, green: 0.91, blue: 0.98)]
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)

                if !isNight && (backgroundID == "morning" || backgroundID == "sunset") {
                    Circle()
                        .fill(Color(red: 1, green: 0.91, blue: 0.68).opacity(0.55))
                        .frame(width: height * 0.75)
                        .blur(radius: 28)
                        .position(x: width * 0.77, y: height * 0.45)
                    Circle()
                        .fill(Color(red: 1, green: 0.96, blue: 0.83))
                        .frame(width: height * 0.24)
                        .position(x: width * 0.77, y: height * 0.45)
                }

                if isNight {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: height * 0.34)
                        .blur(radius: 18)
                        .position(x: width * 0.78, y: height * 0.23)
                    Circle()
                        .fill(Color(red: 1, green: 0.98, blue: 0.84))
                        .frame(width: height * 0.15)
                        .position(x: width * 0.78, y: height * 0.23)
                    ForEach(0..<17, id: \.self) { index in
                        Circle()
                            .fill(.white.opacity(index.isMultiple(of: 3) ? 0.9 : 0.55))
                            .frame(width: index.isMultiple(of: 4) ? 3 : 2)
                            .position(
                                x: width * (0.07 + CGFloat((index * 37) % 86) / 100),
                                y: height * (0.07 + CGFloat((index * 23) % 48) / 100)
                            )
                    }
                } else {
                    cloud(width: width * 0.28, height: height * 0.12)
                        .position(x: width * 0.16, y: height * 0.22)
                    cloud(width: width * 0.20, height: height * 0.09)
                        .position(x: width * 0.84, y: height * 0.32)
                }

                // Overlapping hills make each palette feel like the same landscape.
                Ellipse()
                    .fill(hillColor(back: true))
                    .frame(width: width * 1.22, height: height * 0.62)
                    .position(x: width * 0.87, y: height * 0.92)
                Ellipse()
                    .fill(hillColor(back: false))
                    .frame(width: width * 1.4, height: height * 0.64)
                    .position(x: width * 0.27, y: height * 1.04)

                if accessoryIDs.contains("tree") {
                    sceneTree(size: height * 0.38)
                        .position(x: width * 0.17, y: height * 0.66)
                }
                if accessoryIDs.contains("grass") {
                    grassTuft(size: height * 0.11)
                        .position(x: width * 0.08, y: height * 0.83)
                    grassTuft(size: height * 0.08)
                        .position(x: width * 0.34, y: height * 0.91)
                    grassTuft(size: height * 0.10)
                        .position(x: width * 0.72, y: height * 0.84)
                }
                if accessoryIDs.contains("shrub") {
                    floweringShrub(size: height * 0.25)
                        .position(x: width * 0.85, y: height * 0.77)
                }

                if backgroundID == "garden" {
                    ForEach(0..<9, id: \.self) { index in
                        flower(size: height * (index.isMultiple(of: 3) ? 0.045 : 0.032), color: index.isMultiple(of: 2) ? .white : Color(red: 1, green: 0.83, blue: 0.76))
                            .position(x: width * (0.07 + CGFloat(index) * 0.11), y: height * (index.isMultiple(of: 2) ? 0.79 : 0.88))
                    }
                }

                if effectID == "moonlight" {
                    LinearGradient(colors: [.clear, Color(red: 0.84, green: 0.90, blue: 1).opacity(0.42), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(width: width * 0.30, height: height * 0.74)
                        .rotationEffect(.degrees(-13))
                        .position(x: width * 0.66, y: height * 0.57)
                        .blendMode(.screen)
                }

                if effectID == "sparkle" || effectID == "flowers" || effectID == "moonlight" {
                    ForEach(0..<8, id: \.self) { index in
                        if effectID == "flowers" {
                            flower(size: height * 0.045, color: index.isMultiple(of: 2) ? Color(red: 1, green: 0.85, blue: 0.85) : .white)
                                .position(x: width * (0.12 + CGFloat((index * 31) % 78) / 100), y: height * (0.30 + CGFloat((index * 19) % 48) / 100))
                        } else {
                            SparkleShape()
                                .fill(.white.opacity(index.isMultiple(of: 2) ? 0.92 : 0.64))
                                .frame(width: height * 0.035, height: height * 0.035)
                                .position(x: width * (0.12 + CGFloat((index * 31) % 78) / 100), y: height * (0.23 + CGFloat((index * 19) % 47) / 100))
                        }
                    }
                }

                Image(sheepAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: height * 0.9, height: height * 0.9)
                    // Scope the endless animation to the float offset so layout changes are not animated forever.
                    .animation(animate ? .easeInOut(duration: 3.4).repeatForever(autoreverses: true) : nil) {
                        $0.offset(y: animate ? (floating ? -3 : 2) : 0)
                    }
                    .shadow(color: Color(red: 0.12, green: 0.25, blue: 0.35).opacity(0.18), radius: 8, y: 7)
                    .position(x: width * 0.5, y: height * 0.60)

            }
            .frame(width: width, height: height)
            .clipped()
            .overlay(alignment: .bottom) {
                if fadeIntoStatus {
                    LinearGradient(
                        colors: [.clear, Color(red: 0.9, green: 0.95, blue: 0.99)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: height * 0.14)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ひつじの景色")
        .onAppear { floating = true }
    }

    private func hillColor(back: Bool) -> LinearGradient {
        let colors: [Color]
        if isNight {
            colors = back ? [Color(red: 0.49, green: 0.65, blue: 0.72), Color(red: 0.25, green: 0.48, blue: 0.63)] : [Color(red: 0.57, green: 0.75, blue: 0.72), Color(red: 0.27, green: 0.57, blue: 0.62)]
        } else if backgroundID == "sunset" {
            colors = back ? [Color(red: 0.99, green: 0.83, blue: 0.68), Color(red: 0.80, green: 0.68, blue: 0.75)] : [Color(red: 0.71, green: 0.83, blue: 0.69), Color(red: 0.39, green: 0.67, blue: 0.66)]
        } else {
            colors = back ? [Color(red: 0.83, green: 0.92, blue: 0.77), Color(red: 0.51, green: 0.76, blue: 0.76)] : [Color(red: 0.77, green: 0.91, blue: 0.76), Color(red: 0.36, green: 0.69, blue: 0.69)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private func cloud(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Ellipse().frame(width: width, height: height * 0.75).offset(y: height * 0.15)
            Circle().frame(width: height, height: height).offset(x: -width * 0.16, y: -height * 0.1)
            Circle().frame(width: height * 0.78, height: height * 0.78).offset(x: width * 0.17)
        }
        .foregroundStyle(.white.opacity(0.36))
        .frame(width: width, height: height)
        .blur(radius: 1)
    }

    private func flower(size: CGFloat, color: Color) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Ellipse()
                    .fill(color.opacity(0.85))
                    .frame(width: size * 0.38, height: size * 0.62)
                    .offset(y: -size * 0.26)
                    .rotationEffect(.degrees(Double(index) * 72))
            }
            Circle().fill(Color(red: 1, green: 0.81, blue: 0.44)).frame(width: size * 0.3)
        }
        .frame(width: size, height: size)
    }

    private func sceneTree(size: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: size * 0.025)
                .fill(Color(red: 0.47, green: 0.37, blue: 0.31))
                .frame(width: size * 0.13, height: size * 0.52)
            Circle()
                .fill(Color(red: 0.30, green: 0.62, blue: 0.48))
                .frame(width: size * 0.58)
                .offset(x: -size * 0.18, y: -size * 0.39)
            Circle()
                .fill(Color(red: 0.39, green: 0.72, blue: 0.52))
                .frame(width: size * 0.68)
                .offset(x: size * 0.14, y: -size * 0.42)
            Circle()
                .fill(Color(red: 0.48, green: 0.78, blue: 0.58))
                .frame(width: size * 0.52)
                .offset(x: -size * 0.04, y: -size * 0.65)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func grassTuft(size: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(-2...2, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Color(red: 0.30, green: 0.62, blue: 0.43) : Color(red: 0.43, green: 0.72, blue: 0.48))
                    .frame(width: size * 0.12, height: size * (index == 0 ? 0.9 : 0.7))
                    .rotationEffect(.degrees(Double(index) * 19))
                    .offset(x: size * CGFloat(index) * 0.14)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func floweringShrub(size: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.33, green: 0.65, blue: 0.45))
                .frame(width: size, height: size * 0.60)
            Circle()
                .fill(Color(red: 0.48, green: 0.77, blue: 0.53))
                .frame(width: size * 0.66)
                .offset(x: -size * 0.22, y: -size * 0.13)
            Circle()
                .fill(Color(red: 0.42, green: 0.72, blue: 0.50))
                .frame(width: size * 0.69)
                .offset(x: size * 0.21, y: -size * 0.14)
            flower(size: size * 0.18, color: .white)
                .offset(x: -size * 0.24, y: -size * 0.23)
            flower(size: size * 0.14, color: Color(red: 1, green: 0.84, blue: 0.79))
                .offset(x: size * 0.23, y: -size * 0.13)
            flower(size: size * 0.12, color: .white)
                .offset(x: size * 0.02, y: size * 0.12)
        }
        .frame(width: size, height: size * 0.7)
        .accessibilityHidden(true)
    }
}

private struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: center.y), control: center)
        path.addQuadCurve(to: CGPoint(x: center.x, y: rect.maxY), control: center)
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: center.y), control: center)
        path.addQuadCurve(to: CGPoint(x: center.x, y: rect.minY), control: center)
        return path
    }
}
