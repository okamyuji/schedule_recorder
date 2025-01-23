import UIKit
import Flutter
import AVFoundation
import CallKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let channelName = "com.example.schedule_recorder/audio"
    private var wasRecordingInterrupted = false // 録音中断の追跡

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let methodChannel = FlutterMethodChannel(name: channelName,
                                                 binaryMessenger: controller.binaryMessenger)

        // オーディオセッションの設定
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // mixWithOthersを追加して、他のオーディオと共存できるようにする
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }

        // オーディオセッション中断通知の登録
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        // オーディオルート変更通知の登録
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // オーディオセッション中断の処理
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let methodChannel = FlutterMethodChannel(name: channelName,
                                                 binaryMessenger: controller.binaryMessenger)

        switch type {
        case .began:
            // 通話開始時のみ録音を一時停止
            if AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint {
                wasRecordingInterrupted = true
                methodChannel.invokeMethod("RecordingInterrupted", arguments: nil)
            }
        case .ended:
            if wasRecordingInterrupted {
                // オーディオセッションを再アクティブ化
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("Failed to reactivate audio session: \(error)")
                }
                
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        // 録音を再開可能
                        methodChannel.invokeMethod("RecordingResumed", arguments: nil)
                    }
                }
            }
            // 状態リセット
            wasRecordingInterrupted = false
        default:
            break
        }
    }

    // オーディオルート変更の処理
    @objc private func handleAudioRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let methodChannel = FlutterMethodChannel(name: channelName,
                                                 binaryMessenger: controller.binaryMessenger)

        switch reason {
        case .categoryChange:
            // カテゴリが変更された場合
            let audioSession = AVAudioSession.sharedInstance()
            // 録音カテゴリが失われた場合のみ中断
            if audioSession.category != .playAndRecord && !audioSession.categoryOptions.contains(.mixWithOthers) {
                wasRecordingInterrupted = true
                methodChannel.invokeMethod("RecordingInterrupted", arguments: nil)
            }
        case .oldDeviceUnavailable:
            // 通話開始時のみ録音を一時停止
            if AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint {
                wasRecordingInterrupted = true
                methodChannel.invokeMethod("RecordingInterrupted", arguments: nil)
            }
        case .newDeviceAvailable:
            // 通話が終了した場合
            if wasRecordingInterrupted {
                // オーディオセッションを再アクティブ化
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
                    try AVAudioSession.sharedInstance().setActive(true)
                    methodChannel.invokeMethod("RecordingResumed", arguments: nil)
                } catch {
                    print("Failed to reactivate audio session: \(error)")
                }
                wasRecordingInterrupted = false
            }
        default:
            break
        }
    }
}
