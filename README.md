# NemuChart

NemuChart は、毎朝の短い記録から自分の睡眠リズムを振り返るための iOS アプリです。睡眠時間や起床時の感覚を記録し、日次・週間の傾向、目標への進捗、羊と景色の変化を通して、無理のない習慣づくりを支援します。

> [!NOTE]
> 現在はMVP開発中です。Issue #1〜#10の仕様、基盤、ドメインモデル、永続化まで実装済みです。機能画面は今後のIssueで追加します。

## 目指す体験

- 朝に、ベッド時刻・入眠時刻・起床時刻・スッキリ度を手早く記録する
- 中途覚醒、昼寝、カフェイン、飲酒、スマートフォン利用などを任意で残す
- 日次スコアと内訳を確認し、今夜の目標を決める
- 7日間のグラフと、データ量に応じた控えめな傾向分析を確認する
- 羊の元気度や成長、時間帯に応じた景色の変化を楽しむ
- 目標時刻に合わせた任意のローカル通知を利用する

## プロダクト原則

- **ローカルファースト:** MVPの睡眠データは端末内に保存し、不要な外部送信を行わない
- **非医療:** 診断や治療、睡眠段階の測定を目的とせず、スコアや傾向を断定的に表現しない
- **欠測を尊重:** 未入力を「なし」や0として扱わず、分析に必要なデータが不足している場合はその旨を示す
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

独自アラーム、HealthKit・Apple Watch連携、CloudKit同期、データ書き出し、月間分析、課金はMVPの対象外です。

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

Issue #1〜#10で以下を実装しています。

- MVP仕様、用語、非医療表現、対象外機能の文書化
- iOS 17+のSwiftUIアプリ、Unit Test、UI Testターゲット
- Feature / Repository / Serviceの依存境界
- タイムゾーンとDSTに対応する`SleepDay` / `DateTimeService`
- 睡眠記録、設定、スコア、週間分析、羊、目標の値型
- VersionedSchemaを使用したSwiftData Store
- 睡眠記録、ユーザー設定、睡眠目標のRepository
- 睡眠日重複の検出、既存記録の返却、同一UUIDでの更新

開発項目と依存関係はGitHub Issuesで管理しています。

- [MVP Issues](https://github.com/Hinu10/NemuChart/issues?q=is%3Aissue%20is%3Aopen%20label%3AMVP)
- [今後の構想](https://github.com/Hinu10/NemuChart/issues?q=is%3Aissue%20is%3Aopen%20label%3Afuture)

## 医療上の注意

NemuChartは健康管理を補助する記録ツールであり、医療機器ではありません。表示されるスコア、推定、傾向、フィードバックは診断や医学的助言を提供するものではありません。健康上の不安や持続する強い眠気などがある場合は、医療専門家への相談を検討してください。

## ライセンス

未定です。
