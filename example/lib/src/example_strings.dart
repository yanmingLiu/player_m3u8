import 'player_formatters.dart';

enum ExampleLanguage { zh, en }

class ExampleStrings {
  const ExampleStrings(this.language);

  final ExampleLanguage language;

  bool get _isZh => language == ExampleLanguage.zh;

  String get appTitle => _isZh ? 'M3U8 播放器' : 'M3U8 Player';
  String get languageButtonLabel => _isZh ? 'EN' : '中文';
  String get languageButtonTooltip => _isZh ? '切换到英文' : 'Switch to Chinese';
  String get qoeSnapshotCopied => _isZh ? 'QoE 快照已复制' : 'QoE snapshot copied';
  String get previousVideoTooltip => _isZh ? '上一个视频' : 'Previous video';
  String get nextVideoTooltip => _isZh ? '下一个视频' : 'Next video';
  String get precacheCurrentSourceTooltip =>
      _isZh ? '下载当前播放源' : 'Download current source';
  String get precacheUnsupported =>
      _isZh ? '当前格式不支持下载' : 'Download unsupported for this source';
  String get cancelPrecacheTooltip => _isZh ? '取消下载' : 'Cancel download';
  String get precacheIdle => _isZh ? '下载空闲' : 'Download idle';
  String get precacheCancelled => _isZh ? '下载已取消' : 'Download cancelled';
  String get playTooltip => _isZh ? '播放' : 'Play';
  String get pauseTooltip => _isZh ? '暂停' : 'Pause';
  String get seekBack10Tooltip => _isZh ? '后退 10 秒' : 'Seek back 10 seconds';
  String get seekForward10Tooltip =>
      _isZh ? '前进 10 秒' : 'Seek forward 10 seconds';
  String get muteTooltip => _isZh ? '静音' : 'Mute';
  String get unmuteTooltip => _isZh ? '取消静音' : 'Unmute';
  String get playbackProgressSemantics => _isZh ? '播放进度' : 'Playback progress';
  String get positionLabel => _isZh ? '位置' : 'Position';
  String get durationLabel => _isZh ? '时长' : 'Duration';
  String get playerBufferLabel => _isZh ? '播放器缓冲' : 'Player buffer';
  String get diskCacheLabel => _isZh ? '磁盘缓存' : 'Disk cache';
  String get bufferAheadLabel => _isZh ? '前向缓冲' : 'Buffer ahead';
  String get startupLabel => _isZh ? '启动耗时' : 'Startup';
  String get rebuffersLabel => _isZh ? '卡顿次数' : 'Rebuffers';
  String get rebufferTimeLabel => _isZh ? '卡顿时长' : 'Rebuffer time';
  String get droppedFramesLabel => _isZh ? '丢帧' : 'Dropped frames';
  String get playbackSpeedLabel => _isZh ? '播放速度' : 'Playback speed';
  String get volumeLabel => _isZh ? '音量' : 'Volume';
  String get qualitySwitchesLabel => _isZh ? '清晰度切换' : 'Quality switches';
  String get subtitlesLabel => _isZh ? '字幕' : 'Subtitles';
  String get subtitlesOffLabel => _isZh ? '关闭字幕' : 'Off';
  String get recoveryLabel => _isZh ? '恢复次数' : 'Recovery';
  String get lastRecoveryLabel => _isZh ? '最近恢复' : 'Last recovery';
  String get videoBitrateLabel => _isZh ? '视频码率' : 'Video bitrate';
  String get observedBitrateLabel => _isZh ? '观测码率' : 'Observed bitrate';
  String get sizeLabel => _isZh ? '尺寸' : 'Size';
  String get completeSuffix => _isZh ? ' 完成' : ' complete';
  String get mutedSuffix => _isZh ? ' 静音' : ' muted';
  String get qoeSnapshotsTitle => _isZh ? 'QoE 快照' : 'QoE snapshots';
  String get cacheMetricsTitle => _isZh ? '缓存/下载指标' : 'Cache/download metrics';
  String get downloadListLabel => _isZh ? '下载列表' : 'Downloads';
  String get downloadListTitle => _isZh ? '下载列表' : 'Downloads';
  String get noDownloadTasks => _isZh ? '暂无下载任务' : 'No download tasks';
  String get runningTasksLabel => _isZh ? '运行任务' : 'Running tasks';
  String get queuedTasksLabel => _isZh ? '队列任务' : 'Queued tasks';
  String get failedTasksLabel => _isZh ? '失败任务' : 'Failed tasks';
  String get cacheSizeLabel => _isZh ? '缓存占用' : 'Cache size';
  String get downloadSpeedLabel => _isZh ? '下载速度' : 'Download speed';
  String get bytesProgressLabel => _isZh ? '字节进度' : 'Bytes';
  String get cacheHitLabel => _isZh ? '缓存命中' : 'Cache hits';
  String get networkFetchLabel => _isZh ? '网络下载' : 'Network fetches';
  String get segmentProgressLabel => _isZh ? '分片进度' : 'Segments';
  String get currentDownloadUrlLabel => _isZh ? '当前 URL' : 'Current URL';
  String get retryCountLabel => _isZh ? '重试' : 'Retries';
  String get pauseDownloadTooltip => _isZh ? '暂停下载' : 'Pause download';
  String get resumeDownloadTooltip => _isZh ? '恢复下载' : 'Resume download';
  String get cancelDownloadTooltip => _isZh ? '取消下载' : 'Cancel download';
  String get playerOwnedTaskLabel => _isZh ? '播放器缓存' : 'Player cache';
  String get standaloneTaskLabel => _isZh ? '下载任务' : 'Download task';
  String get copyLatestQoeSnapshotTooltip =>
      _isZh ? '复制最新 QoE 快照' : 'Copy latest QoE snapshot';
  String get qoeWaitingForFirstSample =>
      _isZh ? '等待首个 QoE 采样' : 'QoE waiting for first sample';
  String get retryLabel => _isZh ? '重试' : 'Retry';
  String get playbackErrorTitle => _isZh ? '播放失败' : 'Playback failed';
  String get cacheErrorTitle => _isZh ? '下载失败' : 'Download failed';
  String get actionErrorTitle => _isZh ? '操作失败' : 'Action failed';
  String get autoQualityLabel => _isZh ? '自动' : 'Auto';
  String get unknown => _isZh ? '未知' : 'unknown';
  String get moreTooltip => _isZh ? '更多' : 'More';
  String get fullscreenTooltip => _isZh ? '全屏' : 'Fullscreen';
  String get episodesLabel => _isZh ? '选集' : 'Episodes';
  String episodeCount(int count) => _isZh ? '（共$count集）' : ' ($count episodes)';
  String episodeNumber(int index) => _isZh ? '$index 集' : 'Episode $index';
  String get nowPlayingLabel => _isZh ? '正在播放' : 'Now playing';
  String get notInterestedLabel => downloadListLabel;
  String get watchLaterLabel => _isZh ? '稍后再看' : 'Watch later';
  String get cacheLabel => _isZh ? '缓存' : 'Cache';
  String get cachingLabel => _isZh ? '缓存中' : 'Caching';
  String get pipLabel => _isZh ? '小窗播放' : 'Mini player';
  String get castLabel => _isZh ? '投屏' : 'Cast';
  String get autoPlayNextLabel => _isZh ? '自动连播' : 'Autoplay';
  String get loopPlaybackLabel => _isZh ? '循环播放' : 'Loop';
  String get singleLoopLabel => _isZh ? '单集循环' : 'Single';
  String get playlistLoopLabel => _isZh ? '列表循环' : 'Playlist';
  String get noLoopLabel => _isZh ? '不循环' : 'Off';

  String playbackProgressValue(Duration position, Duration duration) {
    if (_isZh) {
      return '${formatDuration(position)} / ${formatDuration(duration)}';
    }
    return '${formatDuration(position)} of ${formatDuration(duration)}';
  }

  String precacheComplete(String qualitySuffix) {
    return _isZh ? '下载完成$qualitySuffix' : 'Download complete$qualitySuffix';
  }

  String precacheFailed(String error) {
    return _isZh ? '下载失败：$error' : 'Download failed: $error';
  }

  String precaching(String qualitySuffix, String suffix) {
    return _isZh
        ? '正在下载$qualitySuffix$suffix'
        : 'Downloading$qualitySuffix$suffix';
  }

  String latestQoeRebufferRatio(String percent) {
    return _isZh
        ? '最新 QoE：卡顿占比 $percent'
        : 'Latest QoE: rebuffer ratio $percent';
  }

  String qoeDeltas({
    required int rebufferCountDelta,
    required int droppedFramesDelta,
    required int recoveryCountDelta,
    required int qualitySwitchCountDelta,
  }) {
    if (_isZh) {
      return 'QoE 增量：卡顿 +$rebufferCountDelta，'
          '丢帧 +$droppedFramesDelta，'
          '恢复 +$recoveryCountDelta，'
          '清晰度 +$qualitySwitchCountDelta';
    }
    return 'QoE deltas: rebuffer +$rebufferCountDelta, '
        'drop +$droppedFramesDelta, '
        'recover +$recoveryCountDelta, '
        'quality +$qualitySwitchCountDelta';
  }

  String qoeBitrate(String videoBitrate, String observedBitrate) {
    return _isZh
        ? 'QoE 码率：$videoBitrate / $observedBitrate'
        : 'QoE bitrate: $videoBitrate / $observedBitrate';
  }
}
