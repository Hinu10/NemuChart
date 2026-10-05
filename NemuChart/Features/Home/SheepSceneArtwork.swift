import SwiftUI

/// The same little world is used on Home and in the collection previews.
/// Collectibles are drawn as parts of the world rather than floating SF Symbols.
struct SheepSceneArtwork: View {
    let sheepAssetName: String
    var backgroundID: String? = nil
    var effectID: String? = nil
    var accessoryID: String? = nil
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
                    .position(x: width * 0.5, y: height * 0.60)
                    .offset(y: animate ? (floating ? -3 : 2) : 0)
                    .shadow(color: Color(red: 0.12, green: 0.25, blue: 0.35).opacity(0.18), radius: 8, y: 7)
                    .animation(animate ? .easeInOut(duration: 3.4).repeatForever(autoreverses: true) : nil, value: floating)

                if let accessoryID {
                    SheepSceneAccessory(id: accessoryID)
                        .frame(width: height * 0.21, height: height * 0.16)
                        .position(
                            x: width * (accessoryID == "nightcap" ? 0.56 : 0.61),
                            y: height * (accessoryID == "scarf" ? 0.68 : accessoryID == "ribbon" ? 0.52 : 0.49)
                        )
                        .offset(y: animate ? (floating ? -3 : 2) : 0)
                        .animation(animate ? .easeInOut(duration: 3.4).repeatForever(autoreverses: true) : nil, value: floating)
                }
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
}

private struct SheepSceneAccessory: View {
    let id: String

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            switch id {
            case "nightcap":
                ZStack(alignment: .bottomTrailing) {
                    UnevenRoundedRectangle(topLeadingRadius: size.width * 0.8, bottomLeadingRadius: 3, bottomTrailingRadius: size.width * 0.25, topTrailingRadius: 2)
                        .fill(LinearGradient(colors: [Color(red: 0.47, green: 0.53, blue: 0.86), Color(red: 0.26, green: 0.35, blue: 0.66)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: size.width * 0.85, height: size.height * 0.8)
                        .rotationEffect(.degrees(-18))
                    Capsule().fill(.white.opacity(0.92)).frame(height: size.height * 0.18)
                    Circle().fill(.white).frame(width: size.height * 0.25).offset(x: -size.width * 0.65, y: -size.height * 0.58)
                }
            case "scarf":
                ZStack {
                    Ellipse().stroke(Color(red: 0.86, green: 0.45, blue: 0.42), lineWidth: size.height * 0.27)
                    RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.89, green: 0.51, blue: 0.45))
                        .frame(width: size.width * 0.22, height: size.height * 0.7)
                        .rotationEffect(.degrees(-18))
                        .offset(x: size.width * 0.22, y: size.height * 0.32)
                }
            case "ribbon":
                HStack(spacing: 1) {
                    Ellipse().fill(Color(red: 0.94, green: 0.55, blue: 0.67)).rotationEffect(.degrees(25))
                    Circle().fill(Color(red: 0.86, green: 0.39, blue: 0.57)).frame(width: size.width * 0.18)
                    Ellipse().fill(Color(red: 0.94, green: 0.55, blue: 0.67)).rotationEffect(.degrees(-25))
                }
            default:
                EmptyView()
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
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
