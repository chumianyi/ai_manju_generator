import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../models/shot.dart';
import 'ai_service.dart';

/// 视频服务 - 生成、下载、合并、保存
class VideoService {
  static const _channel = MethodChannel('com.qmchat.ai_manju_generator/video');
  final AiService aiService;

  VideoService(this.aiService);

  /// 获取应用文档目录
  Future<String> getAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${dir.path}/videos');
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }
    return videoDir.path;
  }

  /// 为单个镜头生成视频（完整流程：生成提示词 -> 调用视频API -> 轮询 -> 下载）
  Future<Shot> generateShotVideo(
    Shot shot,
    String style,
    String aspectRatio, {
    String quality = '720p',
    Function(String)? onStatus,
    Function(double)? onProgress,
  }) async {
    shot.status = ShotStatus.generating;
    shot.error = null;
    shot.progress = 0.0;

    try {
      // 1. 生成视频提示词（多轮累积，流式）
      onStatus?.call('正在生成镜头${shot.index}的视频提示词...');
      shot.progress = 0.05;
      onProgress?.call(0.05);

      final prompt = await aiService.generateVideoPrompt(
        shot,
        style,
        onStream: (text) {
          onStatus?.call('提示词生成中: ${text.length > 50 ? text.substring(0, 50) + '...' : text}');
        },
      );
      shot.videoPrompt = prompt;
      shot.progress = 0.3;
      onProgress?.call(0.3);

      // 2. 调用视频生成API
      onStatus?.call('正在提交视频生成任务...');
      final result = await aiService.generateVideo(
        prompt: prompt,
        aspectRatio: aspectRatio,
        quality: quality,
        style: style,
      );
      shot.progress = 0.4;
      onProgress?.call(0.4);

      // 3. 获取视频URL（不同API返回格式不同，做兼容处理）
      String? videoUrl;
      String? taskId;
      final isZhipu = aiService.config.videoBaseUrl.contains('bigmodel.cn');

      if (result['data'] != null && result['data'] is List) {
        final data = result['data'][0];
        videoUrl = data['url'] ?? data['video_url'];
        taskId = data['id'] ?? result['id'];
      } else if (result['video_url'] != null) {
        videoUrl = result['video_url'];
      } else if (result['url'] != null) {
        videoUrl = result['url'];
      } else if (result['id'] != null) {
        // 智谱返回 id 作为任务ID
        taskId = result['id'];
      }

      // 4. 如果是异步任务，轮询状态
      if (videoUrl == null && taskId != null) {
        onStatus?.call('视频生成中，请稍候...');
        // 智谱视频生成较慢，增加轮询次数和间隔
        final maxPolls = isZhipu ? 120 : 60;
        final pollInterval = isZhipu ? 3 : 5;

        for (var i = 0; i < maxPolls; i++) {
          await Future.delayed(Duration(seconds: pollInterval));
          try {
            final status = await aiService.getVideoTaskStatus(taskId);
            // 兼容多种状态字段：智谱用 task_status，其他用 status/state
            final state = status['task_status'] ?? status['status'] ?? status['state'];
            final stateLower = state?.toString().toLowerCase();

            // 尝试从API获取真实进度
            final apiProgress = status['progress'] ?? status['percent'] ?? status['percentage'];
            if (apiProgress != null && apiProgress is num) {
              shot.progress = 0.4 + (apiProgress / 100) * 0.5;
            } else {
              shot.progress = 0.4 + (i / maxPolls) * 0.5;
            }
            onProgress?.call(shot.progress);

            // 成功状态：兼容多种写法
            if (stateLower == 'success' || stateLower == 'succeeded' ||
                stateLower == 'completed' || state == 'SUCCESS') {
              // 智谱：video_result[0].url
              if (status['video_result'] != null && status['video_result'] is List) {
                videoUrl = status['video_result'][0]['url'];
              } else if (status['data'] != null && status['data'] is List) {
                videoUrl = status['data'][0]['url'];
              } else {
                videoUrl = status['video_url'] ?? status['url'];
              }
              break;
            } else if (stateLower == 'fail' || stateLower == 'failed' ||
                stateLower == 'error' || state == 'FAIL') {
              // 智谱失败时可能有 error 字段
              final errorMsg = status['error']?['message'] ?? status['error_message'] ?? '视频生成任务失败';
              throw Exception(errorMsg);
            }
          } catch (e) {
            if (e.toString().contains('视频生成任务失败') || e.toString().contains('FAIL')) {
              rethrow;
            }
            // 网络错误等继续轮询
          }
        }
      }

      if (videoUrl == null) {
        throw Exception('无法获取视频URL');
      }
      shot.videoUrl = videoUrl;
      shot.progress = 0.9;
      onProgress?.call(0.9);

      // 5. 下载视频到本地
      onStatus?.call('正在下载视频...');
      final appDir = await getAppDir();
      final fileName = 'shot_${shot.index}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final savePath = '$appDir/$fileName';
      await aiService.downloadVideo(videoUrl, savePath);
      shot.videoPath = savePath;
      shot.status = ShotStatus.completed;
      shot.progress = 1.0;
      onProgress?.call(1.0);
      onStatus?.call('镜头${shot.index}生成完成');
    } catch (e) {
      shot.error = e.toString();
      shot.status = ShotStatus.failed;
      onStatus?.call('镜头${shot.index}生成失败: $e');
      rethrow;
    }
    return shot;
  }

  /// 并发生成所有镜头视频
  /// [concurrency] 并发数，同时生成多少个视频
  /// 返回成功生成的镜头列表
  Future<List<Shot>> generateAllVideosConcurrent(
    List<Shot> shots,
    String style,
    String aspectRatio, {
    String quality = '720p',
    int concurrency = 2,
    Function(String)? onStatus,
    Function(int completed, int total, double overallProgress)? onOverallProgress,
    Function(Shot shot)? onShotComplete,
    Function(Shot shot, Object error)? onShotError,
  }) async {
    final pendingShots = shots.where((s) => s.status != ShotStatus.completed).toList();
    final total = pendingShots.length;
    if (total == 0) return shots;

    // 初始化所有待处理镜头状态
    for (final shot in pendingShots) {
      shot.status = ShotStatus.queued;
      shot.progress = 0.0;
      shot.error = null;
    }

    int completed = 0;
    int currentIndex = 0;
    final completedShots = <Shot>[];

    Future<void> worker() async {
      while (currentIndex < pendingShots.length) {
        final shot = pendingShots[currentIndex++];
        try {
          await generateShotVideo(
            shot,
            style,
            aspectRatio,
            quality: quality,
            onStatus: onStatus,
            onProgress: (p) {
              onOverallProgress?.call(
                completed,
                total,
                (completed + p) / total,
              );
            },
          );
          completed++;
          completedShots.add(shot);
          onShotComplete?.call(shot);
          onOverallProgress?.call(completed, total, completed / total);
        } catch (e) {
          completed++;
          onShotError?.call(shot, e);
          onOverallProgress?.call(completed, total, completed / total);
        }
      }
    }

    // 启动并发 worker
    final workers = List.generate(
      concurrency.clamp(1, 10),
      (_) => worker(),
    );
    await Future.wait(workers);

    return shots;
  }

  /// 合并多个视频为一个（通过原生 MediaMuxer 实现）
  Future<String> mergeVideos(List<Shot> shots, String outputName) async {
    final videoPaths = shots
        .where((s) => s.videoPath != null && File(s.videoPath!).existsSync())
        .map((s) => s.videoPath!)
        .toList();

    if (videoPaths.isEmpty) {
      throw Exception('没有可合并的视频');
    }

    if (videoPaths.length == 1) {
      final appDir = await getAppDir();
      final outputPath = '$appDir/$outputName';
      await File(videoPaths.first).copy(outputPath);
      return outputPath;
    }

    final appDir = await getAppDir();
    final outputPath = '$appDir/$outputName';

    try {
      final result = await _channel.invokeMethod<String>('mergeVideos', {
        'videoPaths': videoPaths,
        'outputPath': outputPath,
      });
      if (result != null && result.isNotEmpty) {
        return result;
      }
      throw Exception('合并失败');
    } on PlatformException catch (e) {
      throw Exception('视频合并失败: ${e.message}');
    }
  }

  /// 保存视频到相册
  Future<bool> saveToGallery(String videoPath) async {
    try {
      final result = await ImageGallerySaverPlus.saveFile(videoPath);
      return result['isSuccess'] == true;
    } catch (e) {
      throw Exception('保存到相册失败: $e');
    }
  }

  /// 删除本地视频文件
  Future<void> deleteVideo(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
