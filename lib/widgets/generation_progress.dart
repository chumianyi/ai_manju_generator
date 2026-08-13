import 'package:flutter/material.dart';

/// 生成进度条 - 显示在右上角
class GenerationProgress extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final String? statusText;
  final bool isGenerating;

  const GenerationProgress({
    super.key,
    required this.progress,
    this.statusText,
    this.isGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isGenerating)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          else
            Icon(
              progress >= 1.0 ? Icons.check_circle : Icons.hourglass_empty,
              size: 16,
              color: progress >= 1.0 ? Colors.green : colorScheme.primary,
            ),
          const SizedBox(width: 8),
          Text(
            statusText ?? '${(progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: LinearProgressIndicator(
              value: progress,
              borderRadius: BorderRadius.circular(4),
              minHeight: 4,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
