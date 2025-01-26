import Flutter
import UIKit
import AVFoundation
import CallKit

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
            binaryMessenger: controller.binaryMessenger
        )
        
        setupCallObserver()
        setupAudioSession()
        
        debugLog("Application launched")
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupCallObserver() {
        callObserver = CXCallObserver()
        callObserver?.setDelegate(self, queue: nil)
        debugLog("CallObserver setup completed")
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setActive(true)
            debugLog("Audio session setup completed")
        } catch {
            debugLog("Failed to setup audio session: \(error.localizedDescription)")
        }
    }

    // デバッグログ出力
    private func debugLog(_ message: String) {
        // 即座にコンソールに出力
        print("[ScheduleRecorder/Native] \(message)")
        // システムログに出力
        NSLog("[ScheduleRecorder/Native] %@", message)
        // Flutterにログを送信
        DispatchQueue.main.async {
            self.methodChannel?.invokeMethod("debugLog", arguments: message)
        }
    }

    private func resetCallState() {
        isHandlingCall = false
        debugLog("Call state reset")
    }
}

extension AppDelegate: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        if call.hasEnded {
            debugLog("CXCallObserver - Call ended")
            
            // 録音状態を確認
            methodChannel?.invokeMethod("GetRecordState", arguments: nil) { result in
                let recordState = (result as? String) ?? "unknown"
                self.debugLog("Current record state: \(recordState)")
                
                // 録音が一時停止状態の場合は、isHandlingCallに関係なく再開を試みる
                if recordState == "pause" {
                    self.debugLog("Recording is paused, attempting to resume")
                    self.isHandlingCall = true  // 確実に再開処理が実行されるようにする
                    
                    // 通話終了後の状態確認と録音再開を複数回試行
                    var attempts = 0
                    let maxAttempts = 3
                    
                    func attemptToResumeRecording() {
                        let audioSession = AVAudioSession.sharedInstance()
                        if !audioSession.isOtherAudioPlaying {
                            self.methodChannel?.invokeMethod("RecordingResumed", arguments: nil)
                            self.debugLog("Recording resumed after confirming no other audio")
                            self.resetCallState()
                        } else {
                            attempts += 1
                            if attempts < maxAttempts {
                                // 0.5秒後に再試行
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    attemptToResumeRecording()
                                }
                                self.debugLog("Retry resuming recording - attempt \(attempts)")
                            } else {
                                self.debugLog("Failed to resume recording after \(maxAttempts) attempts")
                                self.resetCallState()
                            }
                        }
                    }
                    
                    // 最初の試行を1.5秒後に開始
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        attemptToResumeRecording()
                    }
                } else {
                    self.debugLog("Recording is not paused, no need to resume")
                    self.resetCallState()
                }
            }
        } else if !call.isOutgoing && call.hasConnected {
            // 着信時の状態を詳細にログ出力
            debugLog("CXCallObserver - Incoming call state changed")
            debugLog("isOutgoing: \(call.isOutgoing)")
            debugLog("hasConnected: \(call.hasConnected)")
            
            let audioSession = AVAudioSession.sharedInstance()
            // 実際の通話が確立されているかを確認
            if audioSession.isOtherAudioPlaying {
                debugLog("CXCallObserver - Call is actually connected, pausing recording")
                methodChannel?.invokeMethod("RecordingInterrupted", arguments: nil)
                isHandlingCall = true
                debugLog("Set isHandlingCall to true for connected call")
            } else {
                // 通話が確立されていない場合（留守電など）は録音を継続
                debugLog("CXCallObserver - Call is not yet fully connected (possibly voicemail)")
                debugLog("Current audio session state - isOtherAudioPlaying: \(audioSession.isOtherAudioPlaying)")
            }
        } else if call.isOutgoing && call.hasConnected {
            debugLog("CXCallObserver - Outgoing call connected")
            // 発信の場合も同様に実際の通話状態を確認
            if AVAudioSession.sharedInstance().isOtherAudioPlaying {
                debugLog("CXCallObserver - Outgoing call is connected, pausing recording")
                methodChannel?.invokeMethod("RecordingInterrupted", arguments: nil)
                isHandlingCall = true
                debugLog("Set isHandlingCall to true for outgoing call")
            }
        }
    }
}
