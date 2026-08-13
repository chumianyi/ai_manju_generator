# AI 漫剧生成器

基于 Flutter 开发的 AI 漫画短剧视频生成工具，支持 AI 自动分镜、视频生成、合并导出。

## 功能特性

### AI 模型配置
- 支持 OpenAI 兼容协议及自定义协议
- 语言模型（LLM）配置：API 地址、模型名、API Key
- 视频模型配置
- 图片模型配置（可选）
- 支持自定义请求头（Headers）
- 全套 Markdown 识别渲染

### 智能分镜
- 语言模型自动进行剧本分镜
- 自动识别 `<镜头N></镜头N>` 标签
- 系统提示词引导 AI 规范分镜
- 分镜卡片默认折叠，点击展开编辑
- 思考模型支持 `<think></think>` 标签识别
- 思考内容默认折叠，点击可查看
- 思考内容不放入 AI 提示词
- 支持最高 265 万 token 上下文

### 视频生成
- 语言模型调用视频模型生成视频
- 多轮对话累积：一句话跑多次接口，逐次垒起对话历史
- 流式输出：实时显示 AI 响应，无卡顿
- 所有镜头确定后逐个生成
- 视频固定比例（9:16 / 16:9 / 1:1）
- 生成时可选风格（动漫、写实、赛博朋克等）
- 右上角实时进度条

### 视频管理
- 生成视频本地保存
- 内置视频播放器预览
- 全屏放大查看
- 多镜头合并为完整视频
- 保存到系统相册

### UI/UX
- Material 3 / Material You 主题
- 流畅动画过渡
- 折叠/展开交互
- 深色/浅色模式自适应

## 技术栈

- 框架: Flutter 3.x
- 语言: Dart
- UI: Material 3
- 网络: http / dio
- 视频: video_player, chewie, ffmpeg_kit
- 存储: shared_preferences, path_provider
- Markdown: flutter_markdown

## 构建

### 环境要求
- Flutter SDK >= 3.0.0
- Android SDK
- JDK 17

### 编译 APK
```bash
flutter pub get
flutter build apk --release
```

### 分离 ABI 编译
```bash
flutter build apk --release --split-per-abi
```

## 开源协议

本项目采用 GPL 3.0 开源协议。

## GitHub Actions

项目配置了 GitHub Actions 自动编译，推送代码后自动构建 APK。
