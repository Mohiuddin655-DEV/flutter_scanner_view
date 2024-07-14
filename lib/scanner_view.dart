import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

typedef ScannerViewBuilder = Widget Function(
  BuildContext context,
  ScannerController controller,
);

class ScannerView extends StatefulWidget {
  final ScannerController controller;
  final ScannerViewBuilder builder;
  final bool autoInitMode;
  final bool autoDisposeMode;

  const ScannerView({
    super.key,
    required this.controller,
    required this.builder,
    this.autoInitMode = false,
    this.autoDisposeMode = false,
  });

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  @override
  void initState() {
    super.initState();
    if (widget.autoInitMode) widget.controller.init();
  }

  @override
  void dispose() {
    super.dispose();
    if (widget.autoDisposeMode) widget.controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.controller);
  }
}

class ScannerController extends ChangeNotifier {
  final List<BarcodeFormat> formats;

  CameraController? _controller;

  CameraController? get cameraController => _controller;

  BarcodeScanner? _scanner;

  BarcodeScanner? get scanner => _scanner;

  String? _barcode;

  bool get isScanned => _barcode != null && _barcode!.isNotEmpty;

  String? get barcode => _barcode;

  List<CameraDescription>? _cameras;

  List<CameraDescription>? get cameras => _cameras;

  CameraDescription? _camera;

  CameraDescription? get activeCamera => _camera;

  bool _isCameraInitialized = false;

  bool get isCameraInitialized => _isCameraInitialized;

  bool _isProcessing = false;

  bool get isProcessing => _isProcessing;

  ScannerController({
    this.formats = const [BarcodeFormat.all],
  });

  Future<void> init() async {
    _scanner?.close();
    _controller?.dispose();
    _scanner = BarcodeScanner(formats: formats);
    _cameras = await availableCameras();
    _camera = _cameras?.firstOrNull;
    _controller = CameraController(
      _camera!,
      ResolutionPreset.high,
    );
    await _controller?.initialize();
    _isCameraInitialized = true;
    notifyListeners();
    scan();
  }

  Future<void> scan() async {
    if (_isProcessing || isScanned) return;
    _isProcessing = true;
    notifyListeners();
    final picture = await _controller!.takePicture();
    final inputImage = InputImage.fromFilePath(picture.path);
    final barcodes = await _scanner?.processImage(inputImage);
    if (barcodes != null && barcodes.isNotEmpty) {
      final result = barcodes.first.rawValue;
      if (result != null && result.isNotEmpty) {
        log("SCANNED: $result");
        _barcode = result;
        notifyListeners();
      }
    }
    _isProcessing = false;
    notifyListeners();
    scan();
  }

  Future<void> rescan() {
    _barcode = null;
    return scan();
  }

  Future<File?> takePicture() async {
    final x = await _controller?.takePicture();
    if (x != null) {
      return File(x.path);
    } else {
      return null;
    }
  }

  void switchCamera(
    Future<CameraDescription?> Function(
      List<CameraDescription> cameras,
    ) callback,
  ) async {
    final camera = await callback.call(_cameras ?? []);
    if (camera != null) {
      _camera = camera;
      _controller = CameraController(camera, ResolutionPreset.high);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _controller?.dispose();
    _scanner?.close();
  }
}
