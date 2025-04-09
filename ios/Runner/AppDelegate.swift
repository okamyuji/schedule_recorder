import Flutter
import UIKit
import AVFoundation
import CallKit
import Network

@main
@objc class AppDelegate: FlutterAppDelegate {
    // FlutterとのMethodChannel通信に使用する識別子
    private let channelName = "com.example.schedule_recorder/audio"
    // Flutterとの通信チャネル
    private var methodChannel: FlutterMethodChannel?
    // 通話状態の監視
    private var callObserver: CXCallObserver?
    // 通話状態を管理する
    private var isHandlingCall: Bool = false
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        methodChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger)
        
        // メソッドチャネルのハンドラーを設定
        setupMethodChannelHandler()
        
        // 通話の監視を開始
        setupCallObserver()
        
        // アプリ状態の監視を設定
        setupAppStateObserver()
        
        // オーディオセッションの初期設定
        setupAudioSession()
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // メソッドチャネルのハンドラを設定
    private func setupMethodChannelHandler() {
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            switch call.method {
            case "configureAudioSession":
                self.configureAudioSession()
                result(nil)
            case "IsSIPCallActive":
                result(self.isHandlingCall)
            case "directlyResumeRecording":
                self.directlyResumeRecording()
                result(nil)
            case "checkAndInterruptRecording":
                self.checkAndInterruptRecording()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // 通話状態の監視を設定
    private func setupCallObserver() {
        callObserver = CXCallObserver()
        callObserver?.setDelegate(self, queue: nil)
        debugLog("通話監視を開始しました")
    }
    
    // アプリ状態の監視を設定
    private func setupAppStateObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
        
        debugLog("アプリ状態監視を開始しました")
    }
    
    // バックグラウンドに入ったときの処理
    @objc private func appDidEnterBackground() {
        debugLog("アプリがバックグラウンドに移行しました")
        methodChannel?.invokeMethod("RecordingInterrupted", arguments: nil)
    }
    
    // フォアグラウンドに戻ったときの処理
    @objc private func appWillEnterForeground() {
        debugLog("アプリがフォアグラウンドに戻りました")
        // 通話中でない場合に録音を再開
        if !isHandlingCall {
            debugLog("通話中ではないため録音を再開します")
            methodChannel?.invokeMethod("RecordingResumed", arguments: nil)
        } else {
            debugLog("通話中のため録音を再開しません")
        }
    }
    
    // オーディオセッションの初期設定
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            debugLog("オーディオセッションを初期化しました")
        } catch {
            debugLog("オーディオセッション初期化エラー: \(error.localizedDescription)")
        }
    }
    
    // 録音用のオーディオセッションを設定する
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // 一旦セッションを非アクティブにする
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            
            // 録音用のカテゴリとモードを設定
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            
            // サンプルレートとI/Oバッファサイズを設定
            try session.setPreferredSampleRate(44100.0)
            try session.setPreferredIOBufferDuration(0.005)
            
            // セッションをアクティブにする
            try session.setActive(true)
            self.debugLog("オーディオセッションを録音用に設定しました")
        } catch {
            self.debugLog("オーディオセッションの設定に失敗しました: \(error.localizedDescription)")
        }
    }
    
    // 録音を直接再開する（SIP通話終了後、必要なときに呼ばれる）
    private func directlyResumeRecording() {
        self.debugLog("録音の再開を試みています...")
        
        // SIP通話がアクティブかどうかをチェック
        if self.isHandlingCall {
            self.debugLog("SIP通話が進行中のため録音を再開できません")
            return
        }
        
        // オーディオセッションを録音用に再設定
        let session = AVAudioSession.sharedInstance()
        do {
            // 録音用にオーディオセッションを設定
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Flutterへ録音再開を通知
            self.methodChannel?.invokeMethod("RecordingResumed", arguments: nil)
            self.debugLog("録音の再開に成功しました")
        } catch {
            self.debugLog("録音再開時のオーディオセッション設定に失敗しました: \(error.localizedDescription)")
            // エラーが発生した場合もFlutterへ通知
            self.methodChannel?.invokeMethod("RecordingInterrupted", arguments: "AudioSessionError")
        }
    }
    
    // 録音を中断する必要があるかチェックし、必要なら中断する
    private func checkAndInterruptRecording() {
        if isHandlingCall {
            debugLog("通話中のため録音を中断します")
            methodChannel?.invokeMethod("RecordingInterrupted", arguments: nil)
        } else {
            debugLog("通話中ではないため録音を継続します")
        }
    }
    
    // デバッグログ
    private func debugLog(_ message: String) {
        print("【AppDelegate】\(message)")
        methodChannel?.invokeMethod("LogDebugMessage", arguments: message)
    }
}

// MARK: - 通話状態監視
extension AppDelegate: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        if call.hasEnded {
            debugLog("通話が終了しました")
            isHandlingCall = false
            
            // 通話終了後に少し遅延を入れてから録音再開
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                
                // アプリがフォアグラウンドにあるときのみ録音を再開
                if UIApplication.shared.applicationState == .active {
                    self.methodChannel?.invokeMethod("RecordingResumed", arguments: nil)
                    self.debugLog("通話終了後に録音を再開しました")
                }
            }
        } else if call.isOutgoing && call.hasConnected {
            debugLog("発信通話が接続されました")
            isHandlingCall = true
            methodChannel?.invokeMethod("RecordingInterrupted", arguments: nil)
        } else if !call.isOutgoing && call.hasConnected {
            debugLog("着信通話が接続されました")
            isHandlingCall = true
            methodChannel?.invokeMethod("RecordingInterrupted", arguments: nil)
        }
    }
}
