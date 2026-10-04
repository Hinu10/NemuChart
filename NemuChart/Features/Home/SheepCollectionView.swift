import SwiftUI

struct SheepCollectionView: View {
    let growthPoints: Int
    let unlockedIDs: Set<String>
    let sheepAssetName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let ink = Color(red: 0.12, green: 0.18, blue: 0.27)
    private let mutedInk = Color(red: 0.28, green: 0.38, blue: 0.54)

    private var unlockedCount: Int {
        SheepCollectible.all.filter { unlockedIDs.contains($0.id) }.count
    }

    private var nextUnlock: SheepCollectible? {
        SheepCollectible.all
            .filter { !unlockedIDs.contains($0.id) }
            .min { $0.requiredGrowth < $1.requiredGrowth }
    }

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    ForEach(SheepCollectible.Category.allCases, id: \.self) { category in
                        collectionSection(category)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .background(skyBackground.ignoresSafeArea())
            .navigationTitle("コレクション")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("閉じる") { dismiss() } }
        }
        .preferredColorScheme(.light)
    }

    private var skyBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.58, green: 0.78, blue: 0.96),
                Color(red: 0.77, green: 0.90, blue: 0.98),
                Color(red: 0.92, green: 0.88, blue: 0.97),
                Color(red: 0.90, green: 0.95, blue: 0.99)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .topLeading) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 140))
                .foregroundStyle(.white.opacity(0.25))
                .offset(x: -38, y: 46)
                .accessibilityHidden(true)
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.30))
                    .frame(width: 180, height: 180)
                    .blur(radius: 18)
                Image(systemName: "cloud.fill")
                    .font(.system(size: 155))
                    .foregroundStyle(.white.opacity(0.45))
                    .offset(y: 53)
                Image(sheepAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)
                    .accessibilityHidden(true)
            }
            .frame(height: 164)

            Text("ひつじの景色")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(ink)
            Text("記録を重ねると、小物や景色が増えていきます")
                .font(.subheadline)
                .foregroundStyle(mutedInk)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Label("\(growthPoints) pt", systemImage: "sparkles")
                Text("•")
                Text("\(unlockedCount) / \(SheepCollectible.all.count) 解放")
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(.white.opacity(0.55), in: Capsule())

            if let nextUnlock {
                Text("次の解放まで \(max(0, nextUnlock.requiredGrowth - growthPoints)) pt")
                    .font(.caption)
                    .foregroundStyle(mutedInk)
            } else {
                Text("すべてのコレクションを解放しました")
                    .font(.caption)
                    .foregroundStyle(mutedInk)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.60), lineWidth: 1))
    }

    private func collectionSection(_ category: SheepCollectible.Category) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: category.symbol)
                    .font(.headline)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.55), in: Circle())
                Text(category.rawValue)
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            .foregroundStyle(ink)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(SheepCollectible.all.filter { $0.category == category }) { item in
                    collectibleCard(item)
                }
            }
        }
    }

    private func collectibleCard(_ item: SheepCollectible) -> some View {
        let unlocked = unlockedIDs.contains(item.id)

        return VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(previewGradient(for: item.category))
                Image(systemName: item.symbol)
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(unlocked ? Color.indigo : mutedInk.opacity(0.34))
                    .shadow(color: .white.opacity(0.75), radius: 6, y: 2)
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(mutedInk)
                        .padding(7)
                        .background(.white.opacity(0.75), in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(8)
                }
            }
            .frame(height: 92)
            .accessibilityHidden(true)

            Text(unlocked ? item.name : "未解放")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(2)
            Label(
                unlocked ? "解放済み" : "\(item.requiredGrowth) ptで解放",
                systemImage: unlocked ? "checkmark.circle.fill" : "sparkle"
            )
            .font(.caption)
            .foregroundStyle(unlocked ? Color(red: 0.18, green: 0.48, blue: 0.44) : mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.60), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func previewGradient(for category: SheepCollectible.Category) -> LinearGradient {
        let colors: [Color]
        switch category {
        case .accessory:
            colors = [Color(red: 0.90, green: 0.88, blue: 0.99), Color(red: 0.77, green: 0.87, blue: 0.99)]
        case .background:
            colors = [Color(red: 0.72, green: 0.87, blue: 0.99), Color(red: 0.87, green: 0.95, blue: 0.97)]
        case .effect:
            colors = [Color(red: 0.99, green: 0.91, blue: 0.90), Color(red: 0.90, green: 0.87, blue: 0.99)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private extension SheepCollectible.Category {
    var symbol: String {
        switch self {
        case .accessory: "moon.stars.fill"
        case .background: "cloud.sun.fill"
        case .effect: "sparkles"
        }
    }
}
