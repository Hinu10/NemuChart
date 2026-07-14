# アーキテクチャ

## 依存方向

`App / Feature UI → DomainのProtocol・値型 ← Persistence / Service実装`

- **App / Features:** SwiftUI画面と状態管理。`ModelContext`やSwiftDataのモデルを直接参照しない。
- **Domain:** 値型、Validation、Repository Protocol、Service Protocol。SwiftUIとSwiftDataに依存しない。
- **Services:** 日時、スコア、分析、フィードバック、羊状態をそれぞれ独立した責務として実装する。
- **Persistence:** SwiftDataモデル、変換、Repository実装、Schema Migrationを担当する。
- **AppDependencies:** Composition Rootとして具象RepositoryとServiceを生成し、FeatureへProtocolとして注入する。

`ScoringService`は入力からスコアを計算し、`SheepStateService`はスコア等を受けて羊状態を決める。両者を分離し、スコア計算が表示上の演出へ依存しないようにする。`AnalysisService`もProtocol越しに注入し、テストではMockへ交換できる。

## Repository規則

- UIはRepository Protocolを通してのみ保存・取得する。
- `SleepRecord.id`は作成後に変更しない。
- 睡眠日の一意キーは起床地のローカル日付 `yyyy-MM-dd` とする。
- 新規IDで既存睡眠日を保存しようとした場合は上書きせず、既存記録を含む`.duplicate`を返す。
- 同一IDの保存は更新とし、`createdAt`を維持して`updatedAt`を更新する。
- 永続化エラーは`RepositoryError`へ変換し、UIが理由と再試行可否を判断できるようにする。

## 時刻規則

- 実時刻は`Date`、記録時の地域はIANAタイムゾーンIDで保持する。
- 睡眠日は起床時刻を記録時タイムゾーンのCalendarへ投影して決定する。
- 睡眠時間は絶対時刻間の経過秒数として計算し、DSTによる23時間日・25時間日を許容する。
- Calendar、TimeZone、現在時刻は注入可能にし、端末設定やテスト実行時刻から分離する。

## 永続化

SwiftDataのVersionedSchemaを用い、初期バージョンを`1.0.0`とする。本番はApplication Support配下の永続Store、テストとPreviewはインメモリStoreを使用する。MVPではCloudKitを構成しない。

