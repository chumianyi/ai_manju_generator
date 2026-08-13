package com.qmchat.ai_manju_generator

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.qmchat.ai_manju_generator/video"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "mergeVideos") {
                val videoPaths = call.argument<List<String>>("videoPaths") ?: emptyList()
                val outputPath = call.argument<String>("outputPath") ?: ""
                try {
                    val merged = mergeVideos(videoPaths, outputPath)
                    result.success(merged)
                } catch (e: Exception) {
                    result.error("MERGE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun mergeVideos(videoPaths: List<String>, outputPath: String): String {
        if (videoPaths.isEmpty()) throw Exception("No videos to merge")

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var videoTrackIndex = -1
        var audioTrackIndex = -1
        var videoFormat: MediaFormat? = null
        var audioFormat: MediaFormat? = null
        var totalDurationUs = 0L

        // 先扫描所有视频，获取统一的格式（使用第一个视频的格式）
        val firstExtractor = MediaExtractor()
        firstExtractor.setDataSource(videoPaths[0])
        for (i in 0 until firstExtractor.trackCount) {
            val format = firstExtractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("video/") && videoFormat == null) {
                videoFormat = format
            } else if (mime.startsWith("audio/") && audioFormat == null) {
                audioFormat = format
            }
        }
        firstExtractor.release()

        if (videoFormat != null) {
            videoTrackIndex = muxer.addTrack(videoFormat)
        }
        if (audioFormat != null) {
            audioTrackIndex = muxer.addTrack(audioFormat)
        }

        muxer.start()

        val bufferInfo = MediaCodec.BufferInfo()
        val buffer = ByteBuffer.allocate(2 * 1024 * 1024)

        for (path in videoPaths) {
            val extractor = MediaExtractor()
            extractor.setDataSource(path)

            // 找到视频和音频轨道
            var vTrack = -1
            var aTrack = -1
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("video/")) vTrack = i
                else if (mime.startsWith("audio/")) aTrack = i
            }

            // 复制视频帧
            if (vTrack >= 0 && videoTrackIndex >= 0) {
                extractor.selectTrack(vTrack)
                var sawEOS = false
                while (!sawEOS) {
                    bufferInfo.offset = 0
                    bufferInfo.size = extractor.readSampleData(buffer, 0)
                    if (bufferInfo.size < 0) {
                        sawEOS = true
                        bufferInfo.size = 0
                    } else {
                        bufferInfo.presentationTimeUs = extractor.sampleTime + totalDurationUs
                        bufferInfo.flags = extractor.sampleFlags
                        muxer.writeSampleData(videoTrackIndex, buffer, bufferInfo)
                        extractor.advance()
                    }
                }
            }

            // 复制音频帧
            if (aTrack >= 0 && audioTrackIndex >= 0) {
                extractor.selectTrack(aTrack)
                var sawEOS = false
                while (!sawEOS) {
                    bufferInfo.offset = 0
                    bufferInfo.size = extractor.readSampleData(buffer, 0)
                    if (bufferInfo.size < 0) {
                        sawEOS = true
                        bufferInfo.size = 0
                    } else {
                        bufferInfo.presentationTimeUs = extractor.sampleTime + totalDurationUs
                        bufferInfo.flags = extractor.sampleFlags
                        muxer.writeSampleData(audioTrackIndex, buffer, bufferInfo)
                        extractor.advance()
                    }
                }
            }

            // 累加时长
            val duration = getDuration(path)
            totalDurationUs += duration

            extractor.release()
        }

        muxer.stop()
        muxer.release()

        return outputPath
    }

    private fun getDuration(path: String): Long {
        val extractor = MediaExtractor()
        extractor.setDataSource(path)
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("video/")) {
                val duration = format.getLong(MediaFormat.KEY_DURATION)
                extractor.release()
                return duration
            }
        }
        extractor.release()
        return 0L
    }
}
