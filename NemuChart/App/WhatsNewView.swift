import SwiftUI

/// アップデート後の初回起動で見せる「今回の変更」。バージョンを上げるたびに current を書き換える。
struct WhatsNew {
    struct Item: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    let version: String
    let items: [Item]

    static let current = WhatsNew(version: "1.1", items: [
        Item(
            symbol: "alarm.fill",
            title: String(localized: "アラームが使えるようになりました"),
            detail: String(localized: "「今夜の目標」でセット。やさしいメロディーや声の音も選べて、スヌーズは10分です。")
        ),
        Item(
            symbol: "bed.double.fill",
            title: String(localized: "「今から寝る」で記録がかんたんに"),
            detail: String(localized: "寝るときに押して、朝は「起きた！」を押すだけ。寝た時刻と起きた時刻が記録画面に入ります。")
        ),
        Item(
            symbol: "sparkles",
            title: String(localized: "ひつじの景色がにぎやかに"),
            detail: String(localized: "星空の丘やひつじの庭が豪華になり、ホームに過去1週間の記録が加わりました。")
        )
    ])
}

struct WhatsNewView: View {
    let version: WhatsNew
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("ねむちゃーとが \(version.version) になりました 🐑")
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(version.items) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: item.symbol)
                                .font(.title2)
                                .foregroundStyle(.indigo)
                                .frame(width: 34)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.headline)
                                Text(item.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Button("はじめる", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .navigationTitle("今回の変更")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }
}

#Preview {
    WhatsNewView(version: .current) {}
}
