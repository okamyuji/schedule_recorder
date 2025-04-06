import XCTest
import AVFoundation
import CallKit
import Network
@testable import Runner

// モックオブジェクト
class MockMethodChannel: FlutterMethodChannel {
    var methodCalls: [(String, Any?)] = []
    var methodCallHandler: FlutterMethodCallHandler?
    var resultToReturn: Any?
    
    override func setMethodCallHandler(_ handler: FlutterMethodCallHandler?) {
        methodCallHandler = handler
    }
    
    override func invokeMethod(_ method: String, arguments: Any?) {
        methodCalls.append((method, arguments))
    }
    
    func mockMethodCall(_ method: String, arguments: [String: Any]?) {
        let call = FlutterMethodCall(methodName: method, arguments: arguments)
        methodCallHandler?(call) { result in
            if let error = result as? FlutterError {
                print("Error in method call: \(error)")
            } else {
                self.resultToReturn = result
            }
        }
    }
}

class MockCXProvider: CXProvider {
    var reportedCalls: [(UUID, CXCallUpdate)] = []
    
    override func reportNewIncomingCall(with UUID: UUID, update: CXCallUpdate, completion: @escaping (Error?) -> Void) {
        reportedCalls.append((UUID, update))
        completion(nil)
    }
}

class MockCXCallController: CXCallController {
    var requestedTransactions: [CXTransaction] = []
    
    override func request(_ transaction: CXTransaction, completion: @escaping (Error?) -> Void) {
        requestedTransactions.append(transaction)
        completion(nil)
    }
}

class AppDelegateTests: XCTestCase {
    var appDelegate: AppDelegate!
    var mockMethodChannel: MockMethodChannel!
    var mockProvider: MockCXProvider!
    var mockCallController: MockCXCallController!
    
    override func setUp() {
        super.setUp()
        appDelegate = AppDelegate()
        mockMethodChannel = MockMethodChannel(name: "test", binaryMessenger: FlutterBinaryMessengerDummy())
        mockProvider = MockCXProvider(configuration: CXProviderConfiguration(localizedName: "Test"))
        mockCallController = MockCXCallController()
        
        // プロパティの設定
        appDelegate.setValue(mockMethodChannel, forKey: "methodChannel")
        appDelegate.setValue(mockProvider, forKey: "callKitProvider")
        appDelegate.setValue(mockCallController, forKey: "callKitCallController")
    }
    
    override func tearDown() {
        appDelegate = nil
        mockMethodChannel = nil
        mockProvider = nil
        mockCallController = nil
        super.tearDown()
    }
    
    // MARK: - オーディオセッション設定テスト
    
    func testConfigureAudioSessionForRecording() {
        // テスト実行
        appDelegate.perform(NSSelectorFromString("configureAudioSessionForRecording"))
        
        // 検証
        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.category, .playAndRecord)
        XCTAssertEqual(session.mode, .default)
        XCTAssertTrue(session.categoryOptions.contains(.defaultToSpeaker))
        XCTAssertTrue(session.categoryOptions.contains(.allowBluetooth))
    }
    
    // MARK: - ファイル操作テスト
    
    func testVerifyFileExistsAndIsValid() {
        // テストファイルの作成
        let testFilePath = NSTemporaryDirectory().appending("test.txt")
        let testContent = "Test content"
        try? testContent.write(toFile: testFilePath, atomically: true, encoding: .utf8)
        
        // テスト実行
        let exists = appDelegate.perform(NSSelectorFromString("verifyFileExistsAndIsValid:"), with: testFilePath)?.takeUnretainedValue() as? Bool
        
        // 検証
        XCTAssertTrue(exists ?? false)
        
        // クリーンアップ
        try? FileManager.default.removeItem(atPath: testFilePath)
    }
    
    func testGetFileInfo() {
        // テストファイルの作成
        let testFilePath = NSTemporaryDirectory().appending("test.txt")
        let testContent = "Test content"
        try? testContent.write(toFile: testFilePath, atomically: true, encoding: .utf8)
        
        // テスト実行
        let info = appDelegate.perform(NSSelectorFromString("getFileInfo:"), with: testFilePath)?.takeUnretainedValue() as? [String: Any]
        
        // 検証
        XCTAssertNotNil(info)
        XCTAssertTrue(info?["exists"] as? Bool ?? false)
        XCTAssertNotNil(info?["size"])
        XCTAssertNotNil(info?["modificationDate"])
        XCTAssertNotNil(info?["creationDate"])
        
        // クリーンアップ
        try? FileManager.default.removeItem(atPath: testFilePath)
    }
    
    // MARK: - 通話処理テスト
    
    func testHandleNewAudioDeviceConnected() {
        // テスト実行
        appDelegate.perform(NSSelectorFromString("handleNewAudioDeviceConnected"))
        
        // 検証
        XCTAssertTrue(mockMethodChannel.methodCalls.contains { call in
            call.0 == "GetRecordState"
        })
    }
    
    func testHandleAudioDeviceDisconnected() {
        // テスト準備
        appDelegate.setValue(true, forKey: "isHandlingCall")
        
        // テスト実行
        appDelegate.perform(NSSelectorFromString("handleAudioDeviceDisconnected"))
        
        // 検証
        XCTAssertTrue(mockMethodChannel.methodCalls.contains { call in
            call.0 == "GetRecordState"
        })
    }
    
    // MARK: - SIP通話テスト
    
    func testReportSIPCallStarted() {
        // テスト実行
        appDelegate.perform(NSSelectorFromString("reportSIPCallStarted:"), with: "TestDevice")
        
        // 検証
        XCTAssertFalse(mockProvider.reportedCalls.isEmpty)
        let reportedCall = mockProvider.reportedCalls.first
        XCTAssertNotNil(reportedCall)
        XCTAssertEqual(reportedCall?.1.localizedCallerName, "VoIP: TestDevice")
    }
    
    func testReportSIPCallEnded() {
        // テスト準備
        let testUUID = UUID()
        appDelegate.setValue(testUUID, forKey: "currentSIPCallUUID")
        
        // テスト実行
        appDelegate.perform(NSSelectorFromString("reportSIPCallEnded"))
        
        // 検証
        XCTAssertFalse(mockCallController.requestedTransactions.isEmpty)
        let transaction = mockCallController.requestedTransactions.first
        XCTAssertNotNil(transaction)
        XCTAssertTrue(transaction?.actions.first is CXEndCallAction)
    }
    
    // MARK: - CallKit Delegate テスト
    
    func testProviderDidReset() {
        // テスト準備
        appDelegate.setValue(UUID(), forKey: "currentSIPCallUUID")
        appDelegate.setValue(true, forKey: "isHandlingCall")
        
        // テスト実行
        appDelegate.providerDidReset(mockProvider)
        
        // 検証
        XCTAssertNil(appDelegate.value(forKey: "currentSIPCallUUID"))
        XCTAssertFalse(appDelegate.value(forKey: "isHandlingCall") as? Bool ?? true)
    }
    
    func testProviderPerformAnswerCallAction() {
        // テスト実行
        let expectation = XCTestExpectation(description: "Answer call action fulfilled")
        let action = CXAnswerCallAction(call: UUID())
        action.fulfill = { expectation.fulfill() }
        
        appDelegate.provider(mockProvider, perform: action)
        
        // 検証
        wait(for: [expectation], timeout: 1.0)
    }
}

// テスト用のダミーMessenger
class FlutterBinaryMessengerDummy: NSObject, FlutterBinaryMessenger {
    func send(onChannel channel: String, message: Data?, binaryReply: ((Data?) -> Void)?) {}
    func send(onChannel channel: String, message: Data?) {}
    func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler handler: ((Data?) -> (Data?))?) -> FlutterBinaryMessengerConnection { return 0 }
    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}