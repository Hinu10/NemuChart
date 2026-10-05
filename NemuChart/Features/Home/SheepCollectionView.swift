import SwiftUI

struct SheepCollectionView: View {
    let growthPoints: Int
    let unlockedIDs: Set<String>
    let sheepAssetName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedPreviewID: String?

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

    private var previewItem: SheepCollectible? {
        if let selectedPreviewID,
           let item = SheepCollectible.all.first(where: { $0.id == selectedPreviewID && unlockedIDs.contains($0.id) }) {
            return item
        }
        return SheepCollectible.all.last(where: { unlockedIDs.contains($0.id) })
    }

    private func previewID(for category: SheepCollectible.Category) -> String? {
        if previewItem?.category == category { return previewItem?.id }
        return SheepCollectible.all.last(where: { $0.category == category && unlockedIDs.contains($0.id) })?.id
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
            SheepSceneArtwork(
                sheepAssetName: sheepAssetName,
                backgroundID: previewID(for: .background),
                effectID: previewID(for: .effect),
                accessoryID: previewID(for: .accessory)
            )
            .frame(height: 205)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text("ひつじの景色")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(ink)
            Text("記録を重ねると、小物や景色が増えていきます")
                .font(.subheadline)
                .foregroundStyle(mutedInk)
                .multilineTextAlignment(.center)
            if let previewItem {
                Text("表示中：\(previewItem.name)")
                    .font(.caption)
                    .foregroundStyle(mutedInk)
            }

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

        return Button {
            if unlocked { selectedPreviewID = item.id }
        } label: {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                SheepSceneArtwork(
                    sheepAssetName: sheepAssetName,
                    backgroundID: item.category == .background ? item.id : nil,
                    effectID: item.category == .effect ? item.id : nil,
                    accessoryID: item.category == .accessory ? item.id : nil
                )
                .saturation(unlocked ? 1 : 0.2)
                .opacity(unlocked ? 1 : 0.48)
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
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .buttonStyle(.plain)
        .disabled(!unlocked)
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
