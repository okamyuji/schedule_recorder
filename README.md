# Schedule Recorder

Schedule Recorderは、Flutterをベースにした音声を録音し、予定管理に活用できるアプリケーションです。**iOSだけに**最適化された設計と機能を備えています。Androidでは動作しません。

## 特徴

### iOS向けの機能と設計

- Native Audio APIの統合
    - iOSのCore Audioを活用した録音機能を提供。高品質な音声データの録音と再生を可能にします。
- iOSのバックグラウンドタスク対応
    - 録音中でもバックグラウンドで動作可能な設計を採用しています。
- 録音の中断・再開
    - iOSのシステムイベント（例: 着信）にも対応し、録音を中断・再開する機能を提供しています。
- ファイル共有機能
    - iTunesまたはFinderを介したファイル共有に対応
    - 他のアプリとの音声ファイルおよびログファイルの共有が可能

### 全般的な機能

- 音声録音
    - ボタン一つで録音を開始・停止可能。
- 音声再生
    - 録音した音声データを再生。
- エラーハンドリング
    - 不明な操作やエラーを適切に通知。
- プラットフォーム独立性
    - Flutterを採用することで、Androidでも同様の操作性を提供。

## iOS固有の設定

### Info.plist の設定

1. マイク使用権限

    ```xml
    <key>NSMicrophoneUsageDescription</key>
    <string>Microphone access is required to record audio.</string>
    ```

2. バックグラウンド実行の設定

    ```xml
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
        <string>processing</string>
    </array>
    ```

3. ファイル共有の設定

    ```xml
    <key>LSSupportsOpeningDocumentsInPlace</key>
    <true/>
    <key>UIFileSharingEnabled</key>
    <true/>
    ```

4. ファイルタイプの設定

    ```xml
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Audio</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.audio</string>
                <string>public.mp3</string>
                <string>public.mpeg-4-audio</string>
                <string>com.apple.m4a-audio</string>
            </array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Log File</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.text</string>
                <string>public.plain-text</string>
                <string>public.log</string>
            </array>
        </dict>
    </array>
    ```

5. URLスキームの設定

    ```xml
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>schedulerecorder</string>
            </array>
            <key>CFBundleURLName</key>
            <string>com.example.scheduleRecorder</string>
        </dict>
    </array>
    ```

### 設定の効果

1. マイク使用権限
   - アプリがマイクを使用する際のユーザー許可を取得可能に

2. バックグラウンド実行
   - アプリがバックグラウンドでも録音を継続可能に
   - オーディオ処理をバックグラウンドで実行可能に

3. ファイル共有機能
   - iTunesまたはFinderでのファイル共有が可能に
   - アプリ内のドキュメントディレクトリへの直接アクセスが可能に

4. ファイルタイプ対応
   - 音声ファイル（.m4a, .mp3）の共有メニューにアプリが表示
   - テキストファイル（.txt, .log）の共有メニューにアプリが表示
   - これらのファイルを開くアプリとして選択可能に

5. URLスキーム
   - `schedulerecorder://` スキームでアプリを起動可能に
   - 他のアプリからの連携が可能に

## 機能概要

1. 録音機能
   - マイクアイコンのタップで録音を開始。
   - 録音中に一時停止アイコンを表示。
   - 録音一時停止後は、再び録音を開始可能。

2. 再生機能
   - 再生アイコンのタップで録音データを再生。
   - 再生中に停止アイコンを表示。

3. システムイベントの処理
   - 録音中にアプリが中断された場合、自動的に停止。
   - 再開時には前回の録音状態を保持。

4. 録音中に電話が鳴った場合
    - 録音は継続される（状態は変化しない）
    - 「録音中...」のテキストが表示されたまま

5. 録音中に電話に出た場合
    - 自動的に一時停止する（pauseメソッドが呼ばれる）
    - 「録音一時停止中...」のテキストが表示される
    - 再開アイコンが表示される

6. 電話を自分から切った場合
    - 自動的に録音を再開する（resumeメソッドが呼ばれる）
    - 「録音中...」のテキストが表示される
    - 一時停止アイコンが表示される

7. 電話を相手が切った場合
    - 自動的に録音を再開する（resumeメソッドが呼ばれる）
    - 「録音中...」のテキストが表示される
    - 一時停止アイコンが表示される

8. 音声ファイルの統一性
    - 一時停止と再開で同じファイルを使用する（stopメソッドは一度だけ呼ばれる）

## 電話着信時の録音動作仕様

以下のデシジョンテーブルは、電話着信時の録音動作の仕様を示しています：

| **条件**                                | 1 | 2 | 3 | 4 | 5 |
|-----------------------------------|---|---|---|---|---|
| 録音中である                          | Y | Y | Y | Y | N |
| 電話が鳴る                           | Y | Y | Y | Y | - |
| 電話に出る                           | N | N | Y | Y | - |
| 自分から電話を切る                      | Y | N | Y | N | - |
| 相手が電話を切る                       | N | Y | N | Y | - |
| **アクション**                           |   |   |   |   |   |
| 録音を継続する                        | Y | Y | N | N | - |
| 録音を一時停止する                     | N | N | Y | Y | - |
| 録音を再開する                        | N | N | Y | Y | - |
| 一時停止前のデータと再開後のデータを1ファイルにする | Y | Y | Y | Y | - |

### シナリオ説明

1. 録音中に電話が鳴って、電話に出ずに自分で切る
   - 録音は継続される
   - 状態は変化しない

2. 録音中に電話が鳴って、電話に出ずに相手が切る
   - 録音は継続される
   - 状態は変化しない

3. 録音中に電話が鳴って、電話に出て、自分が切る
   - 録音は自動的に一時停止する
   - 通話終了後、自動的に録音を再開する
   - 一時停止前のデータと再開後のデータは1つのファイルに保存される

4. 録音中に電話が鳴って、電話に出て、相手が切る
   - 録音は自動的に一時停止する
   - 通話終了後、自動的に録音を再開する
   - 一時停止前のデータと再開後のデータは1つのファイルに保存される

5. 録音中でない場合
   - 電話着信による影響を受けない

### 注意点

- 録音の一時停止と再開は、電話に出た場合のみ発生します
- 電話に出なかった場合は、録音は継続されます
- 録音再開時は、一時停止前のデータと再開後のデータが1つのファイルに保存されます
- 録音中でない場合は、電話着信による影響を受けません

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
dart run build_runner build --delete-conflicting-outputs

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

- iOSデバイスでの信頼設定
    1. `flutter install`でアプリをインストールした後、アプリを起動する前に以下の設定が必要です
    2. iOSデバイスの「設定」アプリを開く
    3. 「一般」>「VPNとデバイス管理」を選択
    4. 開発者のメールアドレスを選択
    5. 「このデベロッパを信頼」を選択
    6. この設定後、アプリが正常に起動できるようになります

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

3. 署名とプロビジョニングの問題
    - 症状: `No profiles for 'com.example.scheduleRecorder' were found` というエラーが発生
    - 解決手順:
        1. Xcodeで`ios/Runner.xcworkspace`を開く
        2. RunnerプロジェクトのSigningセクションで以下を確認
            - Teamが選択されているか
                - personal teamでもビルドはできます
            - Bundle Identifierが正しく設定されているか
            - Automatically manage signingが有効になっているか
        3. Product > Clean Build Folderを実行
        4. Product > Buildを実行
    - 代替解決策:
        - コマンドラインでビルドする場合は `-allowProvisioningUpdates` オプションを追加:

        ```bash
        flutter build ios --allow-provisioning-updates
        ```

## 開発者向け実装詳細

### iOS側の実装詳細

1. **AVAudioSessionの管理**
   - `setupAudioSession()`メソッドで初期設定
   - カテゴリ: `.playAndRecord`
   - オプション: `.defaultToSpeaker`, `.allowBluetooth`
   - 録音中断時の自動ハンドリング

2. **通話イベントの処理**
   - `CXProviderDelegate`と`CXCallObserverDelegate`による通話状態の監視
   - `AVAudioSession.interruptionNotification`による中断通知の監視
   - 通話開始時の録音一時停止と終了時の再開

3. **録音状態の同期**
   - `RecordingInterrupted`イベント: 録音の一時停止
   - `RecordingResumed`イベント: 録音の再開
   - 状態変更時のMethodChannelを通じたFlutter側への通知

### Flutter側の実装詳細

1. **状態管理**
   - `RecordingStateNotifier`による録音状態の管理
   - 状態遷移: 停止 → 録音中 → 一時停止
   - 各状態でのUI更新とユーザー操作の制御

2. **録音処理**
   - `record`パッケージによる録音機能の実装
   - 録音設定:
     - エンコーダー: `AudioEncoder.aacLc`
     - ビットレート: 128000
     - サンプルレート: 44100

3. **イベントハンドリング**
   - iOS側からのイベントをMethodChannelで受信
   - 録音状態の自動更新
   - エラー発生時のログ出力と状態リセット

### 実装上の注意点

1. **録音の一時停止と再開**
   - 同一ファイルでの録音継続
   - 状態遷移の正確な管理
   - UIの適切な更新

2. **エラーハンドリング**
   - 録音失敗時の適切な状態リセット
   - ユーザーへのエラー通知
   - ログ出力による問題追跡

3. **リソース管理**
   - 録音セッションの適切な開放
   - メモリリークの防止
   - バックグラウンド処理の最適化

### デバッグとトラブルシューティング

1. **ログ出力**
   - 状態変更時のログ
   - エラー発生時の詳細情報
   - 録音操作の実行順序

2. **一般的な問題と解決策**
   - 録音が再開されない: AVAudioSessionの状態を確認
   - 音量が低い: オーディオセッションの設定を確認
   - 状態が不整合: ログを確認し状態遷移を追跡

3. **テスト項目**
   - 手動での一時停止/再開
   - 通話による中断/再開
   - バックグラウンド録音
   - エラー発生時の動作

## 今後の改善点

- 文字列定数の管理
    - 文字列はすべて`lib/constants/strings.dart`で管理する。
- クラウド連携
    - 録音データをクラウドストレージに保存する機能。
- 音声認識
    - 音声データを文字起こしするAPIとの統合。
