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
    // 新しいCallKitプロバイダーを管理
    private var provider: CXProvider?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        methodChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        setupCallKit()
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupCallKit() {
        let providerConfiguration = CXProviderConfiguration(localizedName: "ScheduleRecorder")
        provider = CXProvider(configuration: providerConfiguration)
        provider?.setDelegate(self, queue: nil)
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

extension AppDelegate: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
    }
    
    // 通話開始時（電話に出た時）
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        debugLog("Call answered - pausing recording")
        methodChannel?.invokeMethod("RecordingInterrupted", arguments: nil)
        action.fulfill()
    }
    
    // 通話終了時（電話に出た時）
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        debugLog("Call ended - resuming recording")
        methodChannel?.invokeMethod("RecordingResumed", arguments: nil)
        action.fulfill()
    }
}
