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

/// 清晰度选项
const List<Map<String, String>> _qualityOptions = [
  {'label': '标清 480p', 'value': '480p'},
  {'label': '高清 720p', 'value': '720p'},
  {'label': '全高清 1080p', 'value': '1080p'},
  {'label': '4K 超高清', 'value': '4K'},
];

/// 并发数选项
const List<int> _concurrencyOptions = [1, 2, 3, 4, 5, 8, 10];

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

  // 设置项
  String _selectedQuality = '720p';
  int _concurrency = 2;

  @override
  void initState() {
    super.initState();
    _aiService = AiService(widget.config);
    _videoService = VideoService(_aiService);
    _project = widget.project;
    _shots = List.from(_project.shots);
  }

  /// 显示友好的错误对话框
  void _showErrorDialog(Object error) {
    String title = '生成失败';
    String message = error.toString();
    bool canRetry = false;

    if (error is AiException) {
      switch (error.type) {
        case AiErrorType.rateLimit:
          title = '当前使用人数过多';
          message = '服务器繁忙，请稍后重试。\n建议降低并发数或等待几分钟后再试。';
          canRetry = true;
          break;
        case AiErrorType.invalidApiKey:
          title = 'API Key 无效';
          message = '请检查 API 配置中的 Key 是否正确。';
          break;
        case AiErrorType.networkError:
          title = '网络连接失败';
          message = '请检查网络连接后重试。';
          canRetry = true;
          break;
        case AiErrorType.modelNotFound:
          title = '模型不存在';
          message = '请检查模型名称是否正确，或在 API 配置中选择其他模型。';
          break;
        case AiErrorType.serverError:
          title = '服务器繁忙';
          message = '服务器暂时无法响应，请稍后重试。';
          canRetry = true;
          break;
        case AiErrorType.unknown:
          title = '生成失败';
          message = error.message;
          break;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (canRetry)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _generateAllVideos();
              },
              child: const Text('重试'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 并发生成所有视频
  Future<void> _generateAllVideos() async {
    if (_isGenerating) return;

    if (widget.config.videoBaseUrl.isEmpty || widget.config.videoModel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在 API 配置中配置视频模型')),
      );
      return;
    }

    final pendingCount = _shots.where((s) => s.status != ShotStatus.completed).length;
    if (pendingCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有镜头已生成完成')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _overallProgress = 0;
      _statusText = '正在生成视频...';
    });

    try {
      await _videoService.generateAllVideosConcurrent(
        _shots,
        _project.style,
        _project.aspectRatio,
        quality: _selectedQuality,
        concurrency: _concurrency,
        onStatus: (status) {
          if (mounted) setState(() => _statusText = status);
        },
        onOverallProgress: (completed, total, progress) {
          if (mounted) {
            setState(() {
              _overallProgress = progress;
              _statusText = '已完成 $completed/$total';
            });
          }
        },
        onShotComplete: (shot) {
          if (mounted) setState(() {});
          _project.shots = _shots;
          StorageService.saveProject(_project);
        },
        onShotError: (shot, error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('镜头${shot.index}失败: ${error.toString().length > 50 ? error.toString().substring(0, 50) + '...' : error}')),
            );
          }
        },
      );

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusText = _overallProgress >= 1.0 ? '全部生成完成' : '生成结束';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        _showErrorDialog(e);
      }
    }
  }

  // 停止生成
  void _stopGeneration() {
    setState(() => _isGenerating = false);
    _statusText = '已停止';
  }

  // 合并视频
  Future<void> _mergeVideos() async {
    final completedShots = _shots.where((s) => s.status == ShotStatus.completed && s.videoPath != null).toList();
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
          const SnackBar(content: Text('合并完成')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoDetailScreen(videoPath: mergedPath),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e);
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

  // 显示设置对话框
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('生成设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('视频清晰度', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _qualityOptions.map((q) {
                return ChoiceChip(
                  label: Text(q['label']!),
                  selected: _selectedQuality == q['value'],
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedQuality = q['value']!);
                      Navigator.pop(context);
                      _showSettingsDialog();
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('并发数量（同时生成几个视频）', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _concurrencyOptions.map((c) {
                return ChoiceChip(
                  label: Text('$c 个'),
                  selected: _concurrency == c,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _concurrency = c);
                      Navigator.pop(context);
                      _showSettingsDialog();
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '并发数越高生成越快，但可能触发 API 限流',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _shots.where((s) => s.status == ShotStatus.completed).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(_project.title),
        actions: [
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _isGenerating ? null : _showSettingsDialog,
            tooltip: '生成设置',
          ),
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
          // 设置信息条
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Row(
              children: [
                Icon(Icons.high_quality, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text(_qualityOptions.firstWhere((q) => q['value'] == _selectedQuality)['label']!, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Icon(Icons.bolt, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text('$_concurrency 并发', style: const TextStyle(fontSize: 12)),
                const Spacer(),
                Text('${(_overallProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // 状态条
          if (_isGenerating || _statusText != '准备就绪')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          // 整体进度条
          if (_isGenerating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                value: _overallProgress,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
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
                return _buildShotItem(shot);
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

  Widget _buildShotItem(Shot shot) {
    return Column(
      children: [
        ShotCard(
          shot: shot,
          showVideo: false,
        ),
        // 进度条（生成中或队列中时显示）
        if (shot.status == ShotStatus.generating || shot.status == ShotStatus.queued)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      shot.status == ShotStatus.generating ? Icons.hourglass_empty : Icons.schedule,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      shot.status == ShotStatus.generating ? '生成中 ${(shot.progress * 100).toStringAsFixed(0)}%' : '等待中...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    if (shot.status == ShotStatus.generating)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: shot.progress,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: shot.status == ShotStatus.generating ? shot.progress : 0,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ],
            ),
          ),
        // 失败提示
        if (shot.status == ShotStatus.failed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      shot.error ?? '生成失败',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onErrorContainer),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // 视频预览
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
                margin: const EdgeInsets.only(bottom: 8, top: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayerWidget(videoPath: shot.videoPath!),
                    if (shot.status == ShotStatus.generating)
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
        if (shot.status == ShotStatus.completed && shot.videoPath != null)
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
  }
}
