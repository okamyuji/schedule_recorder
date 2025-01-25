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
  static const errorLoadingFiles = 'ファイル一覧の取得に失敗しました';
  static const errorPlayingFile = '再生に失敗しました';
  static const errorDeletingFile = '削除に失敗しました';

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
  static const logRecorderInit = '録音器を初期化中...';
  static const logMicPermissionGranted = 'マイクの権限が許可されました';
  static const logRecordingPathSet = '録音パスを設定中: ';
  static const logRecorderInitComplete = '録音器の初期化が完了しました';
  static const logRecorderInitError = '録音器の初期化エラー: ';
  static const logRecorderNotInitialized = '録音器が初期化されていません';
  static const logStartingRecording = '録音を開始中...';
  static const logAudioInterruption = 'オーディオの中断を検出';
  static const logAudioResumption = 'オーディオの再開を検出';
  static const logRecordingStarted = '録音が開始されました';
  static const logStoppingRecording = '録音を停止中...';
  static const logRecordingStopped = '録音が停止されました';
  static const logStartingPlayback = '再生を開始中...';
  static const logPlaybackFinished = '再生が完了しました';
  static const logPlaybackStarted = '再生が開始されました';
  static const logStoppingPlayback = '再生を停止中...';
  static const logPlaybackStopped = '再生が停止されました';
  static const logRecordingInterrupted = '録音が中断されました...';
  static const logResumingRecording = '録音を再開中...';
  static const logDisposingRecorder = '録音器と再生器を破棄';
}
