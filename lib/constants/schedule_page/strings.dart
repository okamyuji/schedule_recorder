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
  static const errorLoadingFiles = 'ファイル一覧の取得に失敗しました';
  static const errorPlayingFile = '再生に失敗しました';
  static const errorDeletingFile = '削除に失敗しました';

  // 通知メッセージ
  static const notifyRecordingPaused = '録音を一時停止しました';
  static const notifyRecordingResumed = '録音を再開しました';

  // ファイル共有
  static const shareButtonTooltip = 'ファイルを共有';

  // ログメッセージ
  static const logAppStart = '=== アプリケーションログ開始 ===';
  static const logAppStarted = 'アプリケーションを起動しました';
}
