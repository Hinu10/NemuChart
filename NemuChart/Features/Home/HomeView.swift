import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("NemuChart", systemImage: "moon.stars.fill")
            } description: {
                Text("睡眠リズムを、毎朝少しずつ記録します。")
            } actions: {
                Text("現在、MVPを開発中です")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("NemuChart")
        }
    }
}

#Preview {
    HomeView()
}

