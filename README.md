# NemuChart

NemuChart は、毎朝の短い記録から自分の睡眠リズムを振り返るための iOS アプリです。睡眠時間や起床時の感覚を記録し、日次・週間の傾向、目標への進捗、羊と景色の変化を通して、無理のない習慣づくりを支援します。

> [!NOTE]
> MVPの中核機能とリリース監査を実装済みです。将来機能の一部は検証用であり、正式提供前に実機検証とApp Store設定が必要です。

## 目指す体験

- 朝に、寝た時刻・起床時刻・スッキリ度を手早く記録する
- 中途覚醒、昼寝、カフェイン、飲酒、スマートフォン利用などを任意で残す
- 日次スコアと内訳を確認し、今夜の目標を決める
- 7日間のグラフと、データ量に応じた控えめな傾向分析を確認する
- 羊の元気度や成長、時間帯に応じた景色の変化を楽しむ
- 目標時刻に合わせた任意のローカル通知を利用する

## プロダクト原則

- **ローカルファースト:** MVPの睡眠データは端末内に保存し、不要な外部送信を行わない
- **非医療:** 診断や治療、睡眠段階の測定を目的とせず、スコアや傾向を断定的に表現しない
- **入力負荷を下げる:** 任意項目は操作しなければ「なし」や0回/0分として扱い、分析に必要なデータが不足している場合はその旨を示す
- **穏やかな支援:** 低いスコアを責めたり、羊が死亡・退化したりする設計にしない
- **アクセシビリティ:** Dynamic Type、VoiceOver、ダークモード、Reduce Motionを考慮する
- **ユーザーによる管理:** 個別の記録とすべてのデータをユーザー自身が削除できるようにする

## MVP

MVPでは、次の機能を予定しています。

- 初回設定と睡眠目標
- 朝の睡眠記録、入力検証、過去記録の閲覧・編集
- 日次睡眠スコア、内訳、ルールベースのフィードバック
- 7日集計、週間スコア、信頼度を伴う傾向分析
- 羊の元気度・成長と、時間帯や睡眠状態に応じた景色
- 今夜の目標と週間目標
- 任意のローカル通知
- 設定、安全案内、記録削除、全データ削除

独自アラーム、HealthKit・Apple Watch連携、CloudKit同期、データ書き出し、月間分析、課金はMVPの対象外です。将来機能として、調査設計または端末内データだけを使う試験実装を分離しています。CSV/JSON書き出し、生活要因の比較、30/90日レポート、アラーム結果モデルは設定内の追加機能から試せます。

## 技術構成

現在の構成は次のとおりです。

- iOS 17以降
- Swift / SwiftUI
- SwiftData
- Bundle ID: `com.hinu10.NemuChart`
- XCTestによるUnit Test / UI Test
- Feature単位の構成と、Repository・Serviceによる責務分離
- 外部SDKなしの最小構成

## 開発環境

- Xcode 26以降
- iOS 17以降のSDK
- macOS上のXcode Command Line Tools

外部SDKやパッケージへの依存はありません。

## 睡眠スコア基準

この基準は開発・検証用の README 記載に留め、アプリ全体の説明画面では詳細配点を公開しません。画面上では日次や7日分析の内訳として、実際に得点した項目だけを表示します。

- **合計:** 100点満点。徹夜記録は0点。
- **睡眠時間:** 基準睡眠時間との差で採点する。差が0分なら満点、差が4時間以上なら0点、間は線形に減点する。
- **起床時刻:** 通常の起床時刻との差で採点する。差が0分なら満点、差が3時間以上なら0点、日跨ぎを考慮した最短差分で線形に減点する。
- **スッキリ度:** 5段階入力を線形に換算する。「とても重い」は0%、「ふつう」は50%、「とてもスッキリ」は100%。
- **睡眠の分断:** 中途覚醒回数で採点する。0回なら満点、5回以上なら0点、間は線形に減点する。
- **配点:** 中途覚醒回数が記録されている場合は、睡眠時間40点、起床時刻25点、スッキリ度25点、睡眠の分断10点。分断項目がない古い記録などでは、睡眠時間44点、起床時刻28点、スッキリ度28点に再配分する。
- **対象外:** 飲酒、カフェイン、昼寝、スマートフォン利用、ストレス、快適さ、いびきなどの生活要因は、現時点では日次睡眠スコアの機械的な減点には使わない。

## セットアップ

1. リポジトリをCloneする
2. `NemuChart.xcodeproj`をXcodeで開く
3. `NemuChart` Schemeと任意のiOS 17以降のSimulatorを選択する
4. `⌘R`で実行、`⌘U`でテストする

コマンドラインでは次のようにビルドできます。

```sh
xcodebuild \
  -project NemuChart.xcodeproj \
  -scheme NemuChart \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## ディレクトリ構成

```text
NemuChart/
├── App/          # エントリーポイントと依存の組み立て
├── Core/         # 日時などの共通基盤
├── Domain/       # Swiftの値型とValidation
├── Features/     # SwiftUI画面
├── Persistence/  # SwiftDataとRepository実装
└── Services/     # Service Protocol
```

UIはSwiftDataを直接操作せず、Domainで定義したRepository Protocolを利用します。詳しくは[アーキテクチャ](Documentation/ARCHITECTURE.md)を参照してください。

## 実装状況

Issue #1〜#52で以下を実装・設計しています。

- MVP仕様、用語、非医療表現、対象外機能の文書化
- iOS 17+のSwiftUIアプリ、Unit Test、UI Testターゲット
- Feature / Repository / Serviceの依存境界
- タイムゾーンとDSTに対応する`SleepDay` / `DateTimeService`
- 睡眠記録、設定、スコア、週間分析、羊、目標の値型
- VersionedSchemaを使用したSwiftData Store
- 睡眠記録、ユーザー設定、睡眠目標のRepository
- 睡眠日重複の検出、既存記録の返却、同一UUIDでの更新
- 初回設定から日次結果、今夜の目標、週間分析、羊と景色までのMVP画面
- 通知Opt-in、設定、安全案内、単一記録削除、全データ削除
- Privacy Manifest、CI、リリース受入チェックリスト
- 音選択・スヌーズ・停止結果を保存するアラーム体験の検証モデル
- 最小サンプル数と注意書きを伴う生活要因の関連分析
- 欠損値を保持するCSV/JSON書き出しと、30/90日の長期レポート
- AlarmKit、HealthKit、Apple Watch、睡眠ステージ推定、CloudKit、StoreKitの実装判断

## 既知の制約

- スコアと傾向は本人の入力に基づく参考値で、睡眠段階や医学的状態を測定しません。
- 通常のローカル通知は配信時刻、消音モード、集中モードでの動作を保証できません。
- AlarmKitを使う高度なアラームは対応OS、権限、Widget Extensionを含む別実装が必要です。
- HealthKit、Apple Watch、CloudKit、StoreKitはMVPでは接続しません。
- CI／Simulatorに加え、リリース前に実機VoiceOver、通知、再起動、オフラインの受入確認が必要です。

リリース監査の詳細は[チェックリスト](Documentation/RELEASE_CHECKLIST.md)を参照してください。
将来機能の調査結果と採否は[Future feature decisions](Documentation/FUTURE_FEATURE_DECISIONS.md)を参照してください。

開発項目と依存関係はGitHub Issuesで管理しています。

- [MVP Issues](https://github.com/Hinu10/NemuChart/issues?q=is%3Aissue%20is%3Aopen%20label%3AMVP)
- [今後の構想](https://github.com/Hinu10/NemuChart/issues?q=is%3Aissue%20is%3Aopen%20label%3Afuture)

## 医療上の注意

NemuChartは健康管理を補助する記録ツールであり、医療機器ではありません。表示されるスコア、推定、傾向、フィードバックは診断や医学的助言を提供するものではありません。健康上の不安や持続する強い眠気などがある場合は、医療専門家への相談を検討してください。

## ライセンス

未定です。
