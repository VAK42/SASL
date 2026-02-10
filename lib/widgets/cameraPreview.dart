import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;
  final Widget? overlay;
  const CameraPreviewWidget({super.key, required this.controller, this.overlay});
  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          ?overlay,
        ],
      ),
    );
  }
}