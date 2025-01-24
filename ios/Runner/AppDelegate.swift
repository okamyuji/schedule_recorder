import Flutter
import UIKit
import AVFoundation
import CallKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    // FlutterとのMethodChannel通信に使用する識別子
    private let channelName = "com.example.schedule_recorder/audio"
    // 録音が中断されたかどうかを追跡
    private var wasRecordingInterrupted = false
    // 電話の状態を監視するためのオブザーバー
    private var callCenter: CXCallObserver?
    // Flutterとの通信チャネル
    private var methodChannel: FlutterMethodChannel?
    // 通話が実際に接続されているかを追跡（電話に出たかどうか）
    private var isCallActive = false
    // 着信があったかどうかを追跡
    private var isIncomingCall = false
    // 現在の録音状態を管理
    private var recordingState: RecordingState = .stopped

    // 録音の状態を表す列挙型
    private enum RecordingState {
        case recording  // 録音中
        case paused    // 一時停止中
        case stopped   // 停止中
    }    

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        methodChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        setupAudioSession()
        setupCallObserver()
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // オーディオセッションの初期設定
    // - 録音と再生の両方を許可
    // - Bluetoothデバイスの使用を許可
    // - 他のアプリの音声との混合を許可
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            debugLog("Audio session setup completed successfully")
        } catch {
            debugLog("Failed to setup audio session: \(error.localizedDescription)")
        }
    }

    // オーディオルートの変更を処理するメソッド
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }
        
        switch reason {
        case .categoryChange:
            // 電話着信時などのカテゴリー変更時の処理
            let audioSession = AVAudioSession.sharedInstance()
            if audioSession.category != .playAndRecord && !isIncomingCall {
                // 録音用のカテゴリーから変更され、かつ着信以外の理由の場合のみ中断
                methodChannel?.invokeMethod("RecordingInterrupted", arguments: nil)
                wasRecordingInterrupted = true
            }
        case .oldDeviceUnavailable:
            // イヤホン切断時などの処理
            if !isCallActive && !isIncomingCall {
                methodChannel?.invokeMethod("RecordingInterrupted", arguments: nil)
            }
        default:
            break
        }
    }

    // 録音状態の変更を管理するメソッド
    // 状態変更時の一貫性を保つために使用
    private func handleRecordingStateChange(to newState: RecordingState) {
        recordingState = newState
        switch newState {
        case .recording:
            wasRecordingInterrupted = false
            isIncomingCall = false
        case .paused:
            wasRecordingInterrupted = true
        case .stopped:
            wasRecordingInterrupted = false
            isIncomingCall = false
        }
    }
    
    // 電話の状態を監視するオブザーバーの設定
    private func setupCallObserver() {
        callCenter = CXCallObserver()
        callCenter?.setDelegate(self, queue: nil)
    }

    // デバッグログ出力
    private func debugLog(_ message: String) {
        #if DEBUG
        print("[ScheduleRecorder/Native] \(message)")
        NSLog("[ScheduleRecorder/Native] %@", message)
        if let methodChannel = methodChannel {
            methodChannel.invokeMethod("debugLog", arguments: message)
        }
        #endif
    }
}

// 電話の状態変更を処理するデリゲート
extension AppDelegate: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
         callStateValue(call: call)
        guard let methodChannel = methodChannel else {
            debugLog("MethodChannel is not initialized")
            return
        }
        
        debugLog("Call state changed: hasConnected=\(call.hasConnected), hasEnded=\(call.hasEnded), isCallActive=\(self.isCallActive), isIncomingCall=\(self.isIncomingCall), wasRecordingInterrupted=\(self.wasRecordingInterrupted), recordingState=\(self.recordingState)")
        
        // 新しい着信を検出
        if !call.hasConnected && !call.hasEnded && !isIncomingCall {
            isIncomingCall = true
            debugLog("New incoming call detected - continuing recording")
            // 着信時は録音を継続
            return
        }
        
        // 通話開始（着信応答）時の処理
        if call.hasConnected && recordingState == .recording {
            debugLog("Call connected - interrupting recording")
            isCallActive = true
            handleRecordingStateChange(to: .paused)
            methodChannel.invokeMethod("RecordingInterrupted", arguments: nil)
            
        } else if call.hasEnded {
            debugLog("Call ended - previous state: active=\(isCallActive), interrupted=\(wasRecordingInterrupted)")
            
            // 通話が実際に接続されていた場合のみ再開処理
            if isCallActive && recordingState == .paused {
                debugLog("Call was active and recording was paused - resuming")
                
                // オーディオセッションを再設定
                setupAudioSession()
                
                // 状態をリセット
                isCallActive = false
                isIncomingCall = false
                
                // 録音再開
                debugLog("Sending RecordingResumed event")
                methodChannel.invokeMethod("RecordingResumed", arguments: nil)
                handleRecordingStateChange(to: .recording)
            } else {
                debugLog("No need to resume - call was either rejected or recording wasn't active")
                // 着信拒否または未応答の場合は状態をクリア
                isCallActive = false
                isIncomingCall = false
            }
        }
        
        debugLog("Final state: isCallActive=\(isCallActive), isIncomingCall=\(isIncomingCall), wasRecordingInterrupted=\(wasRecordingInterrupted), recordingState=\(self.recordingState)")
    }

    // 録音を再開すべきかどうかを判断するヘルパーメソッド
    private func shouldResumeRecording(_ call: CXCall) -> Bool {
        return wasRecordingInterrupted
    }

    func callStateValue(call: CXCall) {
        let callState = """
        ========= Call State Changed =========
        isOutgoing:   \(call.isOutgoing)
        hasConnected: \(call.hasConnected)
        hasEnded:     \(call.hasEnded)
        isOnHold:     \(call.isOnHold)
        recordingState: \(recordingState)
        isCallActive:   \(isCallActive)
        isIncomingCall: \(isIncomingCall)
        wasRecordingInterrupted: \(wasRecordingInterrupted)
        ====================================
        """
        debugLog(callState)
    }
}
