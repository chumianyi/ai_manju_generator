import 'dart:io';
import 'package:flutter/material.dart';
import '../models/ai_config.dart';
import '../models/project.dart';
import '../models/shot.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/video_service.dart';
import '../widgets/generation_progress.dart';
import '../widgets/shot_card.dart';
import '../widgets/video_player_widget.dart';
import 'video_detail_screen.dart';

/// 视频生成页面
class GenerateScreen extends StatefulWidget {
  final AiConfig config;
  final ManjuProject project;

  const GenerateScreen({
    super.key,
    required this.config,
    required this.project,
  });

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen> {
  late AiService _aiService;
  late VideoService _videoService;
  late List<Shot> _shots;
  late ManjuProject _project;

  bool _isGenerating = false;
  bool _isMerging = false;
  String _statusText = '准备就绪';
  double _overallProgress = 0;
  int _currentShotIndex = -1;

  @override
  void initState() {
    super.initState();
    _aiService = AiService(widget.config);
    _videoService = VideoService(_aiService);
    _project = widget.project;
    _shots = List.from(_project.shots);
  }

  // 逐个生成所有视频
  Future<void> _generateAllVideos() async {
    if (_isGenerating) return;

    // 检查视频模型配置
    if (widget.config.videoBaseUrl.isEmpty || widget.config.videoModel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置视频模型')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _overallProgress = 0;
    });

    final total = _shots.length;

    for (var i = 0; i < total; i++) {
      if (!_isGenerating) break;

      final shot = _shots[i];
      if (shot.isCompleted && shot.videoPath != null) {
        // 已生成的跳过
        setState(() {
          _overallProgress = (i + 1) / total;
        });
        continue;
      }

      setState(() {
        _currentShotIndex = i;
        _statusText = '正在生成镜头 ${shot.index}...';
      });

      try {
        await _videoService.generateShotVideo(
          shot,
          _project.style,
          _project.aspectRatio,
          onStatus: (status) {
            if (mounted) setState(() => _statusText = status);
          },
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _overallProgress = (i + progress) / total;
              });
            }
          },
        );

        setState(() {
          _shots[i] = shot;
          _overallProgress = (i + 1) / total;
        });

        // 保存进度
        _project.shots = _shots;
        await StorageService.saveProject(_project);
      } catch (e) {
        // 继续下一个
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('镜头${shot.index}失败: $e')),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _isGenerating = false;
        _currentShotIndex = -1;
        _statusText = _overallProgress >= 1.0 ? '全部生成完成' : '已停止';
      });
    }
  }

  // 停止生成
  void _stopGeneration() {
    setState(() => _isGenerating = false);
  }

  // 合并视频
  Future<void> _mergeVideos() async {
    final completedShots = _shots.where((s) => s.isCompleted && s.videoPath != null).toList();
    if (completedShots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可合并的视频')),
      );
      return;
    }

    setState(() => _isMerging = true);

    try {
      final outputName = 'merged_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final mergedPath = await _videoService.mergeVideos(completedShots, outputName);
      _project.mergedVideoPath = mergedPath;
      await StorageService.saveProject(_project);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('合并完成: $mergedPath')),
        );
        // 跳转到详情页
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoDetailScreen(videoPath: mergedPath),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('合并失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMerging = false);
    }
  }

  // 保存单个视频到相册
  Future<void> _saveVideo(Shot shot) async {
    if (shot.videoPath == null) return;
    try {
      await _videoService.saveToGallery(shot.videoPath!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  // 保存合并视频到相册
  Future<void> _saveMergedVideo() async {
    if (_project.mergedVideoPath == null) return;
    try {
      await _videoService.saveToGallery(_project.mergedVideoPath!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _shots.where((s) => s.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_project.title),
        actions: [
          // 右上角进度条
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GenerationProgress(
              progress: _overallProgress,
              statusText: '$completedCount/${_shots.length}',
              isGenerating: _isGenerating,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态条
          if (_isGenerating || _statusText != '准备就绪')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Row(
                children: [
                  if (_isGenerating)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _overallProgress >= 1.0 ? Icons.check_circle : Icons.info_outline,
                      size: 16,
                      color: _overallProgress >= 1.0 ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // 合并视频区域
          if (_project.mergedVideoPath != null)
            Card(
              margin: const EdgeInsets.all(16),
              child: ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('合并视频'),
                subtitle: Text(_project.mergedVideoPath!.split('/').last),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_circle),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoDetailScreen(
                              videoPath: _project.mergedVideoPath!,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.save_alt),
                      onPressed: _saveMergedVideo,
                    ),
                  ],
                ),
              ),
            ),

          // 镜头列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _shots.length,
              itemBuilder: (context, index) {
                final shot = _shots[index];
                return Column(
                  children: [
                    ShotCard(
                      shot: shot,
                      showVideo: false,
                    ),
                    // 视频预览缩略
                    if (shot.videoPath != null && File(shot.videoPath!).existsSync())
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoDetailScreen(
                                  videoPath: shot.videoPath!,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 180,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                VideoPlayerWidget(videoPath: shot.videoPath!),
                                if (index == _currentShotIndex && _isGenerating)
                                  Container(
                                    color: Colors.black54,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // 操作按钮
                    if (shot.isCompleted && shot.videoPath != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _saveVideo(shot),
                              icon: const Icon(Icons.save_alt, size: 18),
                              label: const Text('保存'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideoDetailScreen(
                                      videoPath: shot.videoPath!,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.zoom_in, size: 18),
                              label: const Text('放大'),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_isGenerating)
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _stopGeneration,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  ),
                  child: const Text('停止'),
                ),
              )
            else
              Expanded(
                child: FilledButton.icon(
                  onPressed: _generateAllVideos,
                  icon: const Icon(Icons.play_arrow),
                  label: Text('生成全部视频 ($completedCount/${_shots.length})'),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _isMerging ? null : _mergeVideos,
                icon: _isMerging
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.merge),
                label: const Text('合并视频'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
