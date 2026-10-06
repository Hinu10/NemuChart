# Future feature decisions (#43–#52)

更新日: 2026-07-15

この文書は、MVP後の候補を「今実装するもの」「検証用に限定して実装するもの」「設計だけ行うもの」に分ける。AppleのAPI仕様は更新されるため、実装開始時にリンク先を再確認する。

## #43–#44 アラーム

### 調査結果

- iOS 26以降のAlarmKitは、時刻指定・繰り返し・スヌーズを含むアラームを扱い、通常通知より目立つ提示が可能。ただしユーザー許可、`NSAlarmKitUsageDescription`、実機試験が必要。カウントダウン表示にはWidget Extensionも必要になる。
- iOS 17–25では通常のローカル通知をフォールバック候補にできるが、消音、集中モード、端末状態などにより「必ず鳴る目覚まし」とは表現しない。Critical Alerts entitlementは前提にしない。

Sources: [AlarmKit](https://developer.apple.com/documentation/AlarmKit), [Scheduling an alarm with AlarmKit](https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit)

### 今回の範囲

iOS 26以降はAlarmKitで一回限りのアラームを予約する（今夜の目標画面。設定の追加機能からも開ける）。音は「システム標準」「やさしいチャイム」「やさしいメロディー」「小鳥」「緊急サイレン」「潜水艦の警報」「ジリリ目覚まし」「にぎやかメロディー」と、声の「朝です。起きなさい！」「起床カウントダウン」から選ぶ。オリジナル音は予約時にWAVを生成して `Library/Sounds` に置き `.named` で指定する。声は macOS の `say` 出力を同梱するとライセンス上App Storeで配布できないため、端末の `AVSpeechSynthesizer.write` で台詞を合成してWAVに組み込む。生成に失敗した場合は標準音で予約し、画面で知らせる。許可が拒否されている場合はトグルを戻し、設定アプリでの許可を案内する。

「起きた！」（stop intent）で停止時刻、「スヌーズ」（secondary intent。AlarmKitのカウントダウンはLive Activityのウィジェットが必要なため使わず、10分後に同じ音で予約し直す）で回数を `AlarmResult` に記録し、追加機能の「アラーム音ごとの結果」で音別の平均（スヌーズ回数・止めるまでの時間）を表示する。鳴る前に取り消した予約は結果から除く。iOS 17–25ではアラームUIを表示せず、既存の朝通知のみを使う。

残りは実機での確認（許可拒否、ロック中、消音・集中モード、アプリ終了状態、停止・スヌーズ、音の聞こえ方）で、#113で追跡する。

## #45 HealthKit睡眠データ

設計のみ。HealthKitの `sleepAnalysis` を読み取り専用で利用し、初期版では書き込まない。権限拒否は正常系として手入力を維持する。インポート候補はソース、期間、値、タイムゾーンを保持し、手入力を黙って上書きしない。重複は同一ソースと時間帯で識別し、ユーザーに統合候補を提示する。削除はNemuChart内の取り込み結果だけを対象とし、HealthKit原本を削除しない。

検証項目は権限拒否、権限の一部許可、Apple Watch/他社アプリの重複、睡眠ステージなし、日付跨ぎ、旅行時のタイムゾーン、同期遅延。次の実装単位は権限説明、query adapter、候補レビュー、重複解消、取り込み履歴。

Sources: [Sleep analysis](https://developer.apple.com/documentation/HealthKit/HKCategoryTypeIdentifier/sleepAnalysis), [HealthKit data types](https://developer.apple.com/documentation/healthkit/data-types), [HKCategoryValueSleepAnalysis](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis)

## #46 Apple Watch

設計のみ。iPhone単体の手入力を常に利用可能にし、Watchは入力の補助とHealthKit経由の候補ソースとして扱う。Watch未所持、未接続、低電力、同期遅延、権限なしはすべて正常系。端末間で同じ記録IDを使い、更新日時だけの単純な上書きではなく、手入力とセンサー候補の出所を分離する。

次の実装単位はWatch入力の最小項目、WCSessionキュー、重複排除、オフライン再送、HealthKitソース表示、実機マトリクス試験。WatchがなくてもMVP機能は欠けない。

## #47 生活要因の関連分析

実装済み。飲酒、カフェイン、昼寝について「あり/なし」を比較し、各群5件未満は表示しない。30件未満は信頼度を低、30件以上でも観察データのため中までとする。未入力は0/falseに変換せず除外する。平均スッキリ度の差、群ごとの件数、未補正バイアス、因果関係ではない旨を同時表示する。

## #48 起こしやすい時刻・睡眠ステージ推定

現時点では実装しない。手入力の就床・入眠・起床時刻だけから睡眠ステージや「起こしやすさ」を出すと、測定値と誤認される可能性が高く、追加価値より誤解のリスクが大きい。一般的な睡眠周期の固定値にも依存しない。

再検討条件は、出所と品質を表示できる検証済みセンサーデータ、欠損時に推定を出さない設計、実測との評価計画、ユーザーが通常アラームへ即時に戻せること。採用時も「推定」と表示し、診断・測定とは表現しない。

## #49 CloudKit同期

設計のみ。ローカルファーストを維持し、同期OFF・未ログイン・オフラインでも記録/編集/削除/分析を使えることを必須とする。`NSPersistentCloudKitContainer`相当への移行は機能フラグで段階導入する。

- 競合: フィールド単位の出所を残し、同一手入力の競合は更新日時を候補にしつつユーザー修正を優先する。
- 削除: tombstoneを一定期間保持し、他端末で復活しないようにする。全削除は同期対象全端末へ及ぶことを再確認する。
- 移行: ローカルstoreのバックアップ、schema version、ロールバック可能性、大量データ、アカウント切替を試験する。
- 状態: 同期中/最終同期/要対応を表示し、即時同期を保証しない。

Source: [Syncing a Core Data store with CloudKit](https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit)

## #50 書き出し

実装済み。CSV/JSONにID、睡眠日、タイムゾーン、時刻、スッキリ度、任意要因、作成・更新日時を含める。欠損は空欄/null、明示的なfalse/0とは区別する。共有前に内容を説明し、一時ファイルを作らずTransferableのDataとして共有シートへ渡す。

## #51 長期レポート

実装済み。30日/90日、月別、曜日別、平日/週末を提供する。期間内14件未満は集計を表示しない。欠損日は0として埋めず、各睡眠日のタイムゾーンで曜日を判定する。複数タイムゾーンを含む場合は注記する。

## #52 Free/PaidとStoreKit

設計のみ。商品登録や課金コードはまだ導入しない。

- Free: 記録・編集・削除、基本スコア、安全案内、全削除、CSV/JSON書き出し。
- Paid候補: 高度な生活要因分析、90日レポート、CloudKit同期。健康データの閲覧や安全上必要な説明を課金壁にしない。
- entitlement: StoreKit 2の検証済み `currentEntitlements` を正とし、最後に検証できた状態を端末にキャッシュする。購入失敗や期限切れでユーザーデータを削除しない。
- 復元: ユーザー操作の「購入を復元」からのみ `AppStore.sync()` を呼ぶ。認証画面が出る可能性を事前説明する。
- 表示: 価格、期間、自動更新、無料体験条件、解約導線を購入前に明示する。サブスクリプションは継続価値がある機能だけに使う。

Sources: [In-App Purchase](https://developer.apple.com/in-app-purchase/), [AppStore.sync()](https://developer.apple.com/documentation/storekit/appstore/sync%28%29), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
