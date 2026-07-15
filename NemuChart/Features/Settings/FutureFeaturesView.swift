import SwiftUI
import UniformTypeIdentifiers

struct FutureFeaturesView: View {
    let dependencies: AppDependencies

    var body: some View {
        List {
            Section("試験提供") {
                NavigationLink("アラーム体験の設定") {
                    AlarmExperienceView(preferences: dependencies.preferences)
                }
                NavigationLink("生活要因の傾向") {
                    LifestyleInsightsView(dependencies: dependencies)
                }
                NavigationLink("長期レポート") {
                    LongTermReportsView(dependencies: dependencies)
                }
            }
            Section("データ") {
                NavigationLink("CSV / JSONを書き出す") {
                    DataExportView(dependencies: dependencies)
                }
            }
            Section {
                Text("表示する分析は自己入力から計算した参考情報です。測定、診断、因果関係の判定ではありません。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("追加機能")
    }
}

private struct AlarmExperienceView: View {
    let preferences: AppPreferencesStore
    private let soundPreview = AlarmSoundPreviewService()
    @State private var sound: AlarmSoundChoice = .system
    @State private var scheduledAt = Date()
    @State private var result: AlarmResult?
    @State private var message: String?

    var body: some View {
        Form {
            Section("サウンド") {
                Picker("起床音", selection: $sound) {
                    ForEach(AlarmSoundChoice.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Button("音を試聴") {
                    do { try soundPreview.play(sound) }
                    catch { message = "試聴できませんでした：\(error.localizedDescription)" }
                }
                Button("選択を保存") { saveSound() }
            }
            Section("起床結果の確認") {
                DatePicker("予定時刻", selection: $scheduledAt)
                if result == nil {
                    Button("確認用セッションを開始") { startSession() }
                } else {
                    Button("スヌーズ") { snooze() }
                    Button("停止して結果を保存") { stop() }
                }
            }
            Section("OS上の制約") {
                Text(capabilityText)
                Text("この画面は音の選択とスヌーズ・停止結果のデータモデルを検証します。実際の起床通知はOSの許可や状態に左右され、配信を保証しません。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("アラーム体験")
        .onAppear { sound = preferences.load().alarmSound }
        .alert("保存しました", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(message ?? "") }
    }

    private var mode: AlarmDeliveryMode {
        if #available(iOS 26.0, *) { return .alarmKit }
        return .notificationFallback
    }
    private var capabilityText: String {
        mode == .alarmKit
            ? "このOSではAlarmKitを利用できる可能性があります。実機で許可・サウンド・停止動作の確認が必要です。"
            : "このOSでは通常通知がフォールバック候補です。消音・集中モード等によりアラーム相当の動作は保証できません。"
    }
    private func saveSound() {
        do {
            var data = preferences.load(); data.alarmSound = sound; try preferences.save(data)
            message = "起床音の選択を保存しました。"
        } catch { message = error.localizedDescription }
    }
    private func startSession() {
        result = AlarmResult(scheduledAt: scheduledAt, sound: sound, deliveryMode: mode)
    }
    private func snooze() { result?.snoozeCount += 1 }
    private func stop() {
        guard var stopped = result else { return }
        stopped.stoppedAt = Date()
        do {
            var data = preferences.load()
            data.alarmResults.append(stopped)
            data.alarmResults = Array(data.alarmResults.suffix(30))
            try preferences.save(data)
            result = nil
            message = "停止時刻とスヌーズ\(stopped.snoozeCount)回を保存しました。"
        } catch { message = error.localizedDescription }
    }
}

private struct LifestyleInsightsView: View {
    let dependencies: AppDependencies
    @State private var results: [FactorAssociationResult] = []
    @State private var recordCount = 0
    @State private var errorMessage: String?

    var body: some View {
        List {
            if results.isEmpty {
                ContentUnavailableView(
                    "比較データが不足しています",
                    systemImage: "chart.bar.xaxis",
                    description: Text("各要因について、あり・なし各\(LifestyleAssociationService.minimumSamplesPerGroup)件以上が必要です。現在の全記録は\(recordCount)件です。")
                )
            } else {
                ForEach(results) { result in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.factor.displayName).font(.headline)
                        Text("スッキリ度の平均差：\(result.freshnessDifference, specifier: "%+.2f")")
                        Text("比較：\(result.exposedCount)件 / \(result.comparisonCount)件・信頼度 \(confidenceName(result.confidence))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("読み方") {
                Text("入力済み記録内の相関の可能性です。未入力は除外し、生活リズムや体調など別の要因による偏りは補正していません。因果関係は示しません。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("生活要因の傾向")
        .task { load() }
        .alert("読み込めませんでした", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func load() {
        do {
            let records = try dependencies.sleepRecordRepository.records()
            recordCount = records.count
            results = dependencies.lifestyleAssociationService.analyze(records: records)
        } catch { errorMessage = error.localizedDescription }
    }
    private func confidenceName(_ value: AnalysisConfidence) -> String {
        switch value {
        case .insufficient: "不足"
        case .low: "低"
        case .moderate: "中"
        case .high: "高"
        }
    }
}

private struct LongTermReportsView: View {
    let dependencies: AppDependencies
    @State private var days = 30
    @State private var report: LongTermReport?
    @State private var recordCount = 0

    var body: some View {
        List {
            Picker("期間", selection: $days) {
                Text("30日").tag(30)
                Text("90日").tag(90)
            }
            .pickerStyle(.segmented)
            .onChange(of: days) { _, _ in load() }
            if let report {
                Section("月別") { ForEach(report.monthly) { bucketRow($0) } }
                Section("曜日別") { ForEach(report.weekdays) { bucketRow($0) } }
                Section("平日と週末") {
                    LabeledContent("平日のスッキリ度", value: value(report.weekdayFreshness))
                    LabeledContent("週末のスッキリ度", value: value(report.weekendFreshness))
                }
                if report.timeZoneCount > 1 {
                    Text("複数のタイムゾーンの記録を含みます。各睡眠日の現地時刻で曜日を集計しています。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "長期レポートは準備中",
                    systemImage: "calendar.badge.clock",
                    description: Text("選択期間内に\(LongTermReportService.minimumRecords)件以上必要です。全記録は\(recordCount)件です。")
                )
            }
            Section { Text("欠損日は0として扱いません。集計は参考値で、生活要因との因果関係を示しません。")
                .font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("長期レポート")
        .task { load() }
    }

    @ViewBuilder private func bucketRow(_ bucket: LongTermBucket) -> some View {
        VStack(alignment: .leading) {
            Text(bucket.title).font(.headline)
            Text("\(bucket.recordCount)件・平均 \(duration(bucket.averageDuration))・スッキリ度 \(bucket.averageFreshness, specifier: "%.2f")")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func value(_ value: Double?) -> String { value.map { String(format: "%.2f", $0) } ?? "データ不足" }
    private func duration(_ value: TimeInterval) -> String { "\(Int(value / 3600))時間\(Int(value / 60) % 60)分" }
    private func load() {
        let records = (try? dependencies.sleepRecordRepository.records()) ?? []
        recordCount = records.count
        report = dependencies.longTermReportService.report(records: records, days: days)
    }
}

private struct CSVExport: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { $0.data }
    }
}

private struct JSONExport: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
    }
}

private struct DataExportView: View {
    let dependencies: AppDependencies
    @State private var csv = Data()
    @State private var json = Data()
    @State private var count = 0
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("書き出す内容") {
                Text("睡眠日、タイムゾーン、就床・入眠・起床時刻、スッキリ度、任意の生活要因、作成・更新日時を含む\(count)件です。空欄と false / 0 は区別されます。")
                    .font(.footnote)
            }
            Section("形式") {
                ShareLink(item: CSVExport(data: csv), preview: SharePreview("nemuchart-sleep-records.csv")) {
                    Label("CSVを共有", systemImage: "tablecells")
                }.disabled(count == 0)
                ShareLink(item: JSONExport(data: json), preview: SharePreview("nemuchart-sleep-records.json")) {
                    Label("JSONを共有", systemImage: "curlybraces")
                }.disabled(count == 0)
            }
            Section { Text("共有先を選ぶまでデータは端末外へ送信されません。一時ファイルは作成せず、共有シートへデータを渡します。")
                .font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("データ書き出し")
        .task { load() }
        .alert("書き出せませんでした", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }
    private func load() {
        do {
            let records = try dependencies.sleepRecordRepository.records()
            count = records.count
            csv = dependencies.exportService.csv(records: records)
            json = try dependencies.exportService.json(records: records)
        } catch { errorMessage = error.localizedDescription }
    }
}
