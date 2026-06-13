// LOCATION: lib/screens/sign_camera_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

class SignCameraScreen extends StatefulWidget {
  final String checkMode;
  const SignCameraScreen({super.key, required this.checkMode});

  @override
  State<SignCameraScreen> createState() => _SignCameraScreenState();
}
List<double> _scalerMean = [];
List<double> _scalerStd = [];
class _SignCameraScreenState extends State<SignCameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _availableCameras;
  Interpreter? _tfliteInterpreter;
  PoseDetector? _poseDetector;
  List<String> _labels = [];

  bool _isInitializing = true;
  // Tracks init failure reason separately so camera can still work
  // even if the ML model assets are not yet bundled
  String? _initError;
  bool _isProcessingFrame = false;
  String _realtimePredictionToken = "AWAITING GESTURE...";

  final List<List<double>> _sequenceBuffer = [];
  final int _requiredSequenceLength = 30;
  final int _featuresPerFrame = 51;

  @override
  void initState() {
    super.initState();
    _initializeModelAndHardware();
  }

  Future<void> _initializeModelAndHardware() async {
    // A. Permission
    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
    }
    if (!cameraStatus.isGranted) {
      if (mounted) setState(() {
        _initError = "CAMERA PERMISSION DENIED.\nGo to Settings → Apps → this app → Permissions → Allow Camera.";
        _isInitializing = false;
      });
      return;
    }

    // B. Pose detector (used by both modes)
    try {
      _poseDetector = PoseDetector(options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ));
    } catch (e) {
      debugPrint("PoseDetector init failed: $e");
    }

    // C. Load the correct model based on mode
    try {
      if (widget.checkMode == "Sentences") {
        // Word recognition — LSTM model
        _tfliteInterpreter = await Interpreter.fromAsset(
            'assets/model/sign_language.tflite');
        final labelData = await rootBundle.loadString('assets/model/labels.txt');
        _labels = labelData.split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        debugPrint("LSTM word model loaded. Labels: ${_labels.length}");
      } else {
        // Letter recognition — Random Forest / SVM model
        _tfliteInterpreter = await Interpreter.fromAsset(
            'assets/model/letter_classifier.tflite');
        final labelData =
        await rootBundle.loadString('assets/model/letter_labels.txt');
        _labels = labelData.split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        // Load scaler params for Hu moment normalization
        final scalerJson =
        await rootBundle.loadString('assets/model/scaler_params.json');
        final scalerData = json.decode(scalerJson);
        _scalerMean = List<double>.from(scalerData['mean']);
        _scalerStd = List<double>.from(scalerData['std']);
        debugPrint("Letter model loaded. Labels: ${_labels.length}");
      }
    } catch (e) {
      debugPrint("Model not found: $e");
      if (mounted) setState(() {
        _realtimePredictionToken = "MODEL NOT LOADED";
      });
    }

    // D. Camera
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras == null || _availableCameras!.isEmpty) {
        if (mounted) setState(() {
          _initError = "No cameras found.";
          _isInitializing = false;
        });
        return;
      }
      final targetCamera = _availableCameras!.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _availableCameras!.first,
      );
      _cameraController = CameraController(
        targetCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _cameraController!.initialize();
      if (_tfliteInterpreter != null && _poseDetector != null) {
        await _cameraController!.startImageStream(_processLiveCameraFrame);
      }
    } catch (e) {
      debugPrint("Camera init failed: $e");
      if (mounted) setState(() {
        _initError = "Camera failed to open.\nError: $e";
        _isInitializing = false;
      });
      return;
    }

    if (mounted) setState(() => _isInitializing = false);
  }

  void _processLiveCameraFrame(CameraImage image) async {
    if (_isProcessingFrame ||
        _tfliteInterpreter == null ||
        _poseDetector == null) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) return;

      final List<Pose> poses = await _poseDetector!.processImage(inputImage);
      List<double> frameLandmarks = [];

      if (poses.isNotEmpty) {
        final Pose firstPose = poses.first;
        final targetLandmarks = [
          PoseLandmarkType.nose,
          PoseLandmarkType.leftEye,
          PoseLandmarkType.rightEye,
          PoseLandmarkType.leftEar,
          PoseLandmarkType.rightEar,
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.rightElbow,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.rightWrist,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.rightKnee,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        ];

        for (var type in targetLandmarks) {
          final landmark = firstPose.landmarks[type];
          if (landmark != null) {
            // Normalize by image dimensions to match training pipeline
            frameLandmarks.add(landmark.x / image.width);
            frameLandmarks.add(landmark.y / image.height);
            frameLandmarks.add(landmark.likelihood);
          } else {
            frameLandmarks.addAll([0.0, 0.0, 0.0]);
          }
        }
      }

      if (frameLandmarks.length != _featuresPerFrame) {
        frameLandmarks = List.filled(_featuresPerFrame, 0.0);
      }

      _sequenceBuffer.add(frameLandmarks);
      if (_sequenceBuffer.length > _requiredSequenceLength) {
        _sequenceBuffer.removeAt(0);
      }
      if (_sequenceBuffer.length == _requiredSequenceLength) {
        _runModelInference();
      }
    } catch (e) {
      debugPrint("Frame pipeline failure: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _runModelInference() {
    if (_tfliteInterpreter == null || _labels.isEmpty) return;

    var inputTensor = [List<List<double>>.from(_sequenceBuffer)];
    var outputTensor = List.filled(1, List.filled(_labels.length, 0.0));

    _tfliteInterpreter!.run(inputTensor, outputTensor);

    List<double> scores = outputTensor[0];
    double highestScore = -999.0;
    int bestIndex = 0;
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > highestScore) {
        highestScore = scores[i];
        bestIndex = i;
      }
    }

    if (mounted && bestIndex < _labels.length) {
      setState(() {
        _realtimePredictionToken = _labels[bestIndex].toUpperCase();
      });
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (_cameraController == null || _availableCameras == null) return null;

    final camera = _availableCameras!.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => _availableCameras!.first,
    );

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation =
    InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector?.close();
    _tfliteInterpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show specific error message if init failed
    if (!_isInitializing && _initError != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text("LIVE GESTURE HUD: ${widget.checkMode.toUpperCase()}"),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off,
                    size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 24),
                Text(
                  _initError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: theme.colorScheme.error, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
            title:
            Text("LIVE GESTURE HUD: ${widget.checkMode.toUpperCase()}")),
        body: const Center(
            child: Text("Camera controller not initialized.",
                style: TextStyle(color: Colors.white54))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("LIVE GESTURE HUD: ${widget.checkMode.toUpperCase()}"),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: theme.colorScheme.primary, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(40),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_cameraController!),
                    // Show overlay banner if model not loaded yet
                    if (_tfliteInterpreter == null)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: const Text(
                            "ML MODEL NOT BUNDLED — CAMERA PREVIEW ONLY",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Icon(Icons.blur_circular,
                          color: theme.colorScheme.primary, size: 36),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            margin:
            const EdgeInsets.only(bottom: 24, left: 24, right: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "CURRENT PSL PREDICTION",
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _realtimePredictionToken,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.pop(
                        context, _realtimePredictionToken.toLowerCase());
                  },
                  icon: const Icon(Icons.send_and_archive),
                  label: const Text("USE WORD"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}