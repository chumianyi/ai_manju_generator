import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../models/shot.dart';
import 'ai_service.dart';

/// 视频服务 - 生成、下载、合并、保存
class VideoService {
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
    Function(String)? onStatus,
    Function(double)? onProgress,
  }) async {
    shot.isGenerating = true;
    shot.error = null;

    try {
      // 1. 生成视频提示词（多轮累积，流式）
      onStatus?.call('正在生成镜头${shot.index}的视频提示词...');
      final prompt = await aiService.generateVideoPrompt(
        shot,
        style,
        onStream: (text) {
          onStatus?.call('提示词生成中: ${text.length > 50 ? text.substring(0, 50) + '...' : text}');
        },
      );
      shot.videoPrompt = prompt;
      onProgress?.call(0.3);

      // 2. 调用视频生成API
      onStatus?.call('正在提交视频生成任务...');
      final result = await aiService.generateVideo(
        prompt: prompt,
        aspectRatio: aspectRatio,
        style: style,
      );
      onProgress?.call(0.5);

      // 3. 获取视频URL（不同API返回格式不同，做兼容处理）
      String? videoUrl;
      String? taskId;

      if (result['data'] != null && result['data'] is List) {
        final data = result['data'][0];
        videoUrl = data['url'] ?? data['video_url'];
        taskId = data['id'] ?? result['id'];
      } else if (result['video_url'] != null) {
        videoUrl = result['video_url'];
      } else if (result['url'] != null) {
        videoUrl = result['url'];
      } else if (result['id'] != null) {
        taskId = result['id'];
      }

      // 4. 如果是异步任务，轮询状态
      if (videoUrl == null && taskId != null) {
        onStatus?.call('视频生成中，请稍候...');
        for (var i = 0; i < 60; i++) {
          await Future.delayed(const Duration(seconds: 5));
          try {
            final status = await aiService.getVideoTaskStatus(taskId);
            final state = status['status'] ?? status['state'];
            onProgress?.call(0.5 + (i / 60) * 0.4);

            if (state == 'succeeded' || state == 'completed' || state == 'success') {
              if (status['data'] != null && status['data'] is List) {
                videoUrl = status['data'][0]['url'];
              } else {
                videoUrl = status['video_url'] ?? status['url'];
              }
              break;
            } else if (state == 'failed' || state == 'error') {
              throw Exception('视频生成任务失败');
            }
          } catch (e) {
            // 继续轮询
          }
        }
      }

      if (videoUrl == null) {
        throw Exception('无法获取视频URL');
      }

      shot.videoUrl = videoUrl;
      onProgress?.call(0.9);

      // 5. 下载视频到本地
      onStatus?.call('正在下载视频...');
      final appDir = await getAppDir();
      final fileName = 'shot_${shot.index}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final savePath = '$appDir/$fileName';
      await aiService.downloadVideo(videoUrl, savePath);
      shot.videoPath = savePath;

      shot.isCompleted = true;
      onProgress?.call(1.0);
      onStatus?.call('镜头${shot.index}生成完成');
    } catch (e) {
      shot.error = e.toString();
      shot.isGenerating = false;
      onStatus?.call('镜头${shot.index}生成失败: $e');
      rethrow;
    }

    shot.isGenerating = false;
    return shot;
  }

  /// 合并多个视频为一个
  Future<String> mergeVideos(List<Shot> shots, String outputName) async {
    final videoPaths = shots
        .where((s) => s.videoPath != null && File(s.videoPath!).existsSync())
        .map((s) => s.videoPath!)
        .toList();

    if (videoPaths.isEmpty) {
      throw Exception('没有可合并的视频');
    }

    final appDir = await getAppDir();
    final outputPath = '$appDir/$outputName';

    // 创建 concat 文件列表
    final listFile = File('$appDir/concat_list_${DateTime.now().millisecondsSinceEpoch}.txt');
    final listContent = videoPaths.map((p) => "file '$p'").join('\n');
    await listFile.writeAsString(listContent);

    try {
      // 使用 ffmpeg concat 合并
      final command = '-f concat -safe 0 -i ${listFile.path} -c copy $outputPath';
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        // 如果 copy 失败，尝试重新编码
        final command2 = '-f concat -safe 0 -i ${listFile.path} -c:v libx264 -c:a aac $outputPath';
        final session2 = await FFmpegKit.execute(command2);
        final returnCode2 = await session2.getReturnCode();
        if (!ReturnCode.isSuccess(returnCode2)) {
          throw Exception('视频合并失败');
        }
      }

      return outputPath;
    } finally {
      if (await listFile.exists()) {
        await listFile.delete();
      }
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
