import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/shot.dart';
import 'think_panel.dart';

/// 分镜卡片 - 默认折叠，点击展开编辑
class ShotCard extends StatefulWidget {
  final Shot shot;
  final Function(Shot)? onEdit;
  final bool showVideo;

  const ShotCard({
    super.key,
    required this.shot,
    this.onEdit,
    this.showVideo = false,
  });

  @override
  State<ShotCard> createState() => _ShotCardState();
}

class _ShotCardState extends State<ShotCard> {
  bool _expanded = false;
  late TextEditingController _contentController;
  late TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.shot.content);
    _promptController = TextEditingController(text: widget.shot.videoPrompt ?? '');
  }

  @override
  void didUpdateWidget(ShotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shot.content != widget.shot.content) {
      _contentController.text = widget.shot.content;
    }
    if (oldWidget.shot.videoPrompt != widget.shot.videoPrompt) {
      _promptController.text = widget.shot.videoPrompt ?? '';
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          // 标题栏 - 点击折叠/展开
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 序号徽章
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.shot.index}',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 预览内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.shot.content.length > 60
                              ? '${widget.shot.content.substring(0, 60)}...'
                              : widget.shot.content,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (widget.shot.thinkContent != null) ...[
                              Icon(Icons.psychology, size: 14, color: colorScheme.tertiary),
                              const SizedBox(width: 4),
                              Text('含思考', style: TextStyle(fontSize: 12, color: colorScheme.tertiary)),
                              const SizedBox(width: 8),
                            ],
                            if (widget.shot.isCompleted) ...[
                              Icon(Icons.check_circle, size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                              const Text('已生成', style: TextStyle(fontSize: 12, color: Colors.green)),
                            ] else if (widget.shot.isGenerating) ...[
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 4),
                              const Text('生成中', style: TextStyle(fontSize: 12)),
                            ] else if (widget.shot.error != null) ...[
                              Icon(Icons.error, size: 14, color: colorScheme.error),
                              const SizedBox(width: 4),
                              Text('失败', style: TextStyle(fontSize: 12, color: colorScheme.error)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 展开箭头
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
          // 展开内容
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(context),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),

          // 思考面板（如果有）
          if (widget.shot.thinkContent != null)
            ThinkPanel(content: widget.shot.thinkContent!),

          // 镜头内容编辑
          Text('镜头内容', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _contentController,
            maxLines: null,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: '编辑镜头内容...',
            ),
            onChanged: (value) {
              widget.shot.content = value;
              widget.onEdit?.call(widget.shot);
            },
          ),
          const SizedBox(height: 16),

          // 视频提示词
          Text('视频提示词', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            maxLines: null,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'AI生成的视频提示词，可手动编辑...',
            ),
            onChanged: (value) {
              widget.shot.videoPrompt = value;
              widget.onEdit?.call(widget.shot);
            },
          ),

          // 视频预览
          if (widget.shot.videoPath != null && widget.showVideo) ...[
            const SizedBox(height: 16),
            Text('视频预览', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.play_circle, size: 48, color: Colors.white54),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
