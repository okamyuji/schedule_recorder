import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Audio Sessionの初期設定
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }

        // 中断通知の登録
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    @objc func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        let methodChannel = FlutterMethodChannel(name: "com.example.schedule_recorder/audio",
                                                 binaryMessenger: (window?.rootViewController as! FlutterViewController).binaryMessenger)

        if type == .began {
            // 録音中断イベントをFlutterに通知
            methodChannel.invokeMethod("RecordingInterrupted", arguments: nil)
        } else if type == .ended {
            // 録音再開イベントをFlutterに通知
            methodChannel.invokeMethod("RecordingResumed", arguments: nil)
        }
    }
}
