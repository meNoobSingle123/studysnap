import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'package:nhom_7/core/l10n/strings.dart';
import 'package:nhom_7/features/notes/domain/utils/timestamp_helper.dart';

/// Trình phát video bài giảng hỗ trợ Split-View và Mini-Player nổi (120×68 dp)
/// theo đặc tả mục 6.3, 7.1 và FR-15, FR-16 (CĐ 6).
class LectureVideoPlayer extends StatefulWidget {
  final String? videoPath;
  final List<TimestampEntry> timestamps;
  final bool isMini;
  final ValueChanged<String?>? onVideoChanged;
  final ValueChanged<Duration>? onInsertTimestamp;
  final VideoPlayerController? customController;
  final ChewieController? customChewieController;

  const LectureVideoPlayer({
    super.key,
    this.videoPath,
    this.timestamps = const [],
    this.isMini = false,
    this.onVideoChanged,
    this.onInsertTimestamp,
    this.customController,
    this.customChewieController,
  });

  @override
  State<LectureVideoPlayer> createState() => LectureVideoPlayerState();
}

class LectureVideoPlayerState extends State<LectureVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;

  VideoPlayerController? get activeController =>
      widget.customController ?? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant LectureVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath ||
        oldWidget.customController != widget.customController) {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    _disposeControllers();
    _hasError = false;
    _isInitialized = false;

    // Use injected custom controller if provided (e.g. in tests)
    if (widget.customController != null) {
      _controller = widget.customController;
      _isInitialized = _controller!.value.isInitialized;
      if (widget.customChewieController != null) {
        _chewieController = widget.customChewieController;
      } else if (_isInitialized) {
        _setupChewie();
      }
      if (mounted) setState(() {});
      return;
    }

    final path = widget.videoPath;
    if (path == null || path.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final file = File(path);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
        return;
      }

      final controller = VideoPlayerController.file(file);
      _controller = controller;

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _setupChewie();
      setState(() {
        _isInitialized = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _setupChewie() {
    final controller = activeController;
    if (controller == null) return;

    _chewieController?.dispose();
    _chewieController = ChewieController(
      videoPlayerController: controller,
      aspectRatio: controller.value.aspectRatio > 0
          ? controller.value.aspectRatio
          : 16 / 9,
      autoPlay: false,
      looping: false,
      showControls: true,
      allowFullScreen: true,
      allowMuting: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Theme.of(context).colorScheme.primary,
        bufferedColor: Colors.grey,
        backgroundColor: Colors.black26,
      ),
    );
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _chewieController = null;

    if (widget.customController == null) {
      _controller?.dispose();
    }
    _controller = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Pause playback to release resources and save battery
      activeController?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeControllers();
    super.dispose();
  }

  /// Tua video đến đúng mốc thời gian [target] (sai số <= 1 giây).
  Future<void> seekTo(Duration target) async {
    final controller = activeController;
    if (controller != null && controller.value.isInitialized) {
      await controller.seekTo(target);
      if (!controller.value.isPlaying) {
        await controller.play();
      }
      if (mounted) setState(() {});
    }
  }

  /// Lấy số giây hiện tại của video và kích hoạt callback chèn mốc.
  void insertCurrentTimestamp() {
    final controller = activeController;
    final position = controller?.value.position ?? Duration.zero;
    widget.onInsertTimestamp?.call(position);
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        widget.onVideoChanged?.call(picked.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.videoSelectFailed)),
        );
      }
    }
  }

  void _togglePlayPause() {
    final controller = activeController;
    if (controller != null && controller.value.isInitialized) {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMini) {
      return _buildMiniPlayer();
    }
    return _buildStandardPlayer();
  }

  /// Mini-Player nổi kích thước 120×68 dp theo FR-15 khi bàn phím ảo mở.
  Widget _buildMiniPlayer() {
    final controller = activeController;
    final isInitialized = controller?.value.isInitialized ?? false;
    final isPlaying = controller?.value.isPlaying ?? false;

    return Semantics(
      label: AppStrings.videoMiniPlayerTitle,
      child: Container(
        width: 120,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isInitialized && controller != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width > 0
                      ? controller.value.size.width
                      : 120,
                  height: controller.value.size.height > 0
                      ? controller.value.size.height
                      : 68,
                  child: VideoPlayer(controller),
                ),
              )
            else
              const Center(
                child: Icon(Icons.videocam_outlined, color: Colors.white54, size: 28),
              ),

            // Semi-transparent overlay with touch target >= 48dp
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _togglePlayPause,
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Trình phát Split-View bình thường ở nửa trên màn hình.
  Widget _buildStandardPlayer() {
    final hasVideo = (widget.videoPath != null && widget.videoPath!.isNotEmpty) ||
        widget.customController != null;

    if (!hasVideo) {
      return Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const Icon(Icons.video_library_outlined),
          title: const Text(AppStrings.videoAttach),
          subtitle: const Text('Split-View & chèn mốc thời gian [mm:ss]'),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: _pickVideo,
        ),
      );
    }

    if (_hasError) {
      return Container(
        height: 160,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error, size: 36),
              const SizedBox(height: 8),
              Text(
                AppStrings.videoPlayerError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.refresh),
                label: const Text(AppStrings.videoChange),
              ),
            ],
          ),
        ),
      );
    }

    final controller = activeController;
    final chewie = _chewieController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Video Display Container (16:9 aspect ratio, max 200dp height for Split-View)
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: chewie != null
                      ? Chewie(controller: chewie)
                      : (controller != null && controller.value.isInitialized)
                          ? VideoPlayer(controller)
                          : const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Colors.white54,
                                size: 48,
                              ),
                            ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // 2. Action Control Bar: Gắn mốc, Đổi video, Gỡ video
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: insertCurrentTimestamp,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text(AppStrings.videoTimestampButton),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text(AppStrings.videoChange),
            ),
            const Spacer(),
            IconButton(
              tooltip: AppStrings.videoRemove,
              onPressed: () => widget.onVideoChanged?.call(null),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),

        // 3. Horizontal Timestamp Quick-Seek Chip Bar (FR-16)
        if (widget.timestamps.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.timestamps.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final entry = widget.timestamps[index];
                return ActionChip(
                  avatar: const Icon(Icons.play_circle_fill, size: 16),
                  label: Text(entry.tag),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => seekTo(entry.duration),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 12),
      ],
    );
  }
}
