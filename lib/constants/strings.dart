/// アプリケーション全体で使用される文字列定数
class Strings {
  // アプリ全般
  static const appTitle = 'Schedule Recorder';

  // SchedulePage - 録音関連
  static const recordingRecording = '録音中...';
  static const recordingPaused = '録音一時停止中...';
  static const recordingPlaying = '再生中...';
  static const recordingStartTooltip = '録音開始';
  static const recordingStopTooltip = '録音停止';
  static const recordingPauseTooltip = '録音一時停止';
  static const recordingResumeTooltip = '録音再開';
  static const recordingPlayTooltip = '再生開始';
  static const recordingPlayStopTooltip = '再生停止';

  // エラーメッセージ
  static const errorMicPermissionRequired = 'マイクの権限が必要です';
  static const errorRecordingStartFailed = '録音の開始に失敗しました';
  static const errorRecordingPauseFailed = '録音の一時停止に失敗しました';
  static const errorRecordingResumeFailed = '録音の再開に失敗しました';

  // 通知メッセージ
  static const notifyRecordingPaused = '録音を一時停止しました';
  static const notifyRecordingResumed = '録音を再開しました';

  // ファイル共有
  static const shareButtonTooltip = 'ファイルを共有';
  static const shareNoFilesToShare = '共有可能なファイルが見つかりません';
  static const shareStartSharing = 'ファイル共有を開始します';
  static const shareAddAudioFile = '録音ファイルを共有リストに追加: ';
  static const shareAddLogFile = 'ログファイルを共有リストに追加: ';
  static const shareComplete = 'ファイル共有が完了しました';

  // ファイル受信
  static const receiveStartProcessing = '共有されたファイルの処理を開始: ';
  static const receiveAudioFile = '音声ファイルを受信: ';
  static const receiveLogFile = 'ログファイルを受信: ';
  static const receiveUnsupportedFormat = '未対応のファイル形式: ';
  static const receiveFileCopyComplete = 'ファイルをコピーしました: ';
  static const receiveFileCopyFailed = 'ファイルのコピーに失敗: ';
  static const receiveAudioFileSuccess = '音声ファイルを受信しました';
  static const receiveLogFileSuccess = 'ログファイルを受信しました';
  static const receiveProcessingFailed = 'ファイルの処理に失敗しました';

  // ログメッセージ
  static const logAppStart = '=== アプリケーションログ開始 ===';
  static const logAppStarted = 'アプリケーションを起動しました';
  static const logFilePath = 'ログファイルパス: ';
  static const logRecorderInit = 'Initializing recorder...';
  static const logMicPermissionGranted = 'Microphone permission granted';
  static const logRecordingPathSet = 'Recording path set to: ';
  static const logRecorderInitComplete =
      'Recorder initialization completed successfully';
  static const logRecorderInitError = 'Recorder initialization error: ';
  static const logRecorderNotInitialized = 'Recorder is not initialized yet';
  static const logStartingRecording = 'Starting recording...';
  static const logAudioInterruption = 'Audio interruption detected';
  static const logAudioResumption = 'Audio resumption detected';
  static const logRecordingStarted = 'Recording started successfully';
  static const logStoppingRecording = 'Stopping recording...';
  static const logRecordingStopped = 'Recording stopped';
  static const logStartingPlayback = 'Starting playback...';
  static const logPlaybackFinished = 'Playback finished';
  static const logPlaybackStarted = 'Playback started';
  static const logStoppingPlayback = 'Stopping playback...';
  static const logPlaybackStopped = 'Playback stopped';
  static const logRecordingInterrupted = 'Recording interrupted...';
  static const logResumingRecording = 'Resuming recording...';
  static const logDisposingRecorder = 'Recorder and Player disposed';
}
