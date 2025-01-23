# Schedule Recorder

Schedule Recorderは、Flutterをベースにした音声を録音し、予定管理に活用できるアプリケーションです。iOSおよびAndroidの両プラットフォームで動作しますが、特にiOSに最適化された設計と機能を備えています。

## 特徴

### iOS向けの機能と設計

- Native Audio APIの統合
    - iOSのCore Audioを活用した録音機能を提供。高品質な音声データの録音と再生を可能にします。
- iOSのバックグラウンドタスク対応
    - 録音中でもバックグラウンドで動作可能な設計を採用しています。
- 録音の中断・再開
    - iOSのシステムイベント（例: 着信）にも対応し、録音を中断・再開する機能を提供しています。

### 全般的な機能

- 音声録音
    - ボタン一つで録音を開始・停止可能。
- 音声再生
    - 録音した音声データを再生。
- エラーハンドリング
    - 不明な操作やエラーを適切に通知。
- プラットフォーム独立性
    - Flutterを採用することで、Androidでも同様の操作性を提供。

## 機能概要

1. 録音機能
   - 「Start Recording」ボタンで録音を開始。
   - 録音中に「Stop Recording」ボタンを表示。
   - 録音中断後は、再び録音を開始可能。

2. 再生機能
   - 「Play Recording」ボタンで録音データを再生。
   - 再生中に「Stop Playing」ボタンを表示。

3. システムイベントの処理
   - 録音中にアプリが中断された場合、自動的に停止。
   - 再開時には前回の録音状態を保持。

4. 録音中に電話が鳴った場合
    - 録音は継続される（状態は変化しない）
    - 「録音中...」のテキストが表示されたまま

5. 録音中に電話に出た場合
    - 自動的に一時停止する（pauseメソッドが呼ばれる）
    - 「録音一時停止中...」のテキストが表示される
    - 「再開」ボタンが表示される

6. 電話を切った場合
    - 自動的に録音を再開する（resumeメソッドが呼ばれる）
    - 「録音中...」のテキストが表示される
    - 「一時停止」ボタンが表示される

7. 音声ファイルの統一性
    - 一時停止と再開で同じファイルを使用する（stopメソッドは一度だけ呼ばれる）

## 設計詳細

### アーキテクチャ

- MVCパターン
    - UIとロジックを分離して、テスト可能性と保守性を向上。
- サービスレイヤー
    - AudioServiceを用いて、音声録音・再生機能を統一的に管理。
- NativeとFlutterの連携
    - MethodChannelを活用して、FlutterとiOSのネイティブコードを効率的に接続。
    - swiftのコードは`ios/Runner/AppDelegate.swift`を参照してください。

### 主なクラスと役割

- `SchedulePage`: ユーザーインターフェースを管理。
- `AudioService`: 録音・再生のロジックを提供。
- `FlutterSound`: 録音・再生のためのプラグインを使用。

### iOS向け設計

- MethodChannelによるNative APIの呼び出し
    - 録音イベント（中断・再開）をハンドリング。
- バックグラウンドオーディオセッション
    - iOS特有のバックグラウンド処理を適用。

## テスト

### ユニットテスト

- 録音と再生のボタン操作
    - UI操作をモックして、各状態が正しく遷移するかを確認。
- AudioServiceのメソッドテスト
    - iOSのネイティブイベント（例: `RecordingInterrupted`）が正しくハンドリングされることを確認。

### 実行方法

```bash
# ユニットテストに必要なMockを作成する
dart run build_runner build

# ユニットテストを実行する
flutter test
```

## インストールとセットアップ

- Flutterのインストール
    - Flutterがインストールされていない場合は、公式サイトを参照してセットアップしてください。
    - Flutter自体のバージョン管理には`fvm`を使用しています。
- プロジェクトのセットアップ
    - リポジトリをクローン後、以下を実行します。

    ```bash
    flutter pub get
    flutter run
    ```

- iOSのビルド
    - Xcodeを用いてiOS向けにビルドする場合:

    ```bash
    open ios/Runner.xcworkspace
    Xcodeでターゲットを選択し、ビルドを実行。
    ```

## トラブルシューティング

### 一般的な問題

1. マイク権限の問題
    - 症状: 録音が開始されない
    - 解決: iOSの設定でマイク権限がこのアプリに許可されているかを確認
    - 解決: ios/Runner/Info.plistのマイク権限を確認

    ```xml
    <key>NSMicrophoneUsageDescription</key>
    <string>Microphone access is required to record audio.</string>
    ```

    - 解決: ios/Podfileのマイク権限を確認

    ```ruby
    post_install do |installer|
    installer.pods_project.targets.each do |target|
        flutter_additional_ios_build_settings(target)

        target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
            '$(inherited)',
            ## dart: PermissionGroup.microphone
            'PERMISSION_MICROPHONE=1',
        ]
        end
    end
    end
    ```

2. バックグラウンド録音
    - 症状: バックグラウンドで録音が停止
    - 解決: ios/Runner/Info.plistのバックグラウンド設定を確認

    ```xml
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
        <string>processing</string>
    </array>
    ```

## 今後の改善点

- クラウド連携
    - 録音データをクラウドストレージに保存する機能。
- 音声認識
    - 音声データを文字起こしするAPIとの統合。
