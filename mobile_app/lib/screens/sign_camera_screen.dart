// LOCATION: lib/screens/sign_camera_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

// ── Skeleton bone pairs ─────────────────────────────────────────────────────
const List<(PoseLandmarkType, PoseLandmarkType)> _kBones = [
  (PoseLandmarkType.leftShoulder,  PoseLandmarkType.rightShoulder),
  (PoseLandmarkType.leftShoulder,  PoseLandmarkType.leftElbow),
  (PoseLandmarkType.leftElbow,     PoseLandmarkType.leftWrist),
  (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
  (PoseLandmarkType.rightElbow,    PoseLandmarkType.rightWrist),
  (PoseLandmarkType.leftShoulder,  PoseLandmarkType.leftHip),
  (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
  (PoseLandmarkType.leftHip,       PoseLandmarkType.rightHip),
  (PoseLandmarkType.leftHip,       PoseLandmarkType.leftKnee),
  (PoseLandmarkType.leftKnee,      PoseLandmarkType.leftAnkle),
  (PoseLandmarkType.rightHip,      PoseLandmarkType.rightKnee),
  (PoseLandmarkType.rightKnee,     PoseLandmarkType.rightAnkle),
  (PoseLandmarkType.nose,          PoseLandmarkType.leftEye),
  (PoseLandmarkType.nose,          PoseLandmarkType.rightEye),
  (PoseLandmarkType.leftEye,       PoseLandmarkType.leftEar),
  (PoseLandmarkType.rightEye,      PoseLandmarkType.rightEar),
];

// ── Skeleton painter ────────────────────────────────────────────────────────
class _SkeletonPainter extends CustomPainter {
  final Pose?   pose;
  final Size    imageSize;      // ML Kit coordinate space (after rotation)
  final int     sensorAngle;   // 0, 90, 180, 270
  final bool    isFront;

  const _SkeletonPainter({
    required this.pose,
    required this.imageSize,
    required this.sensorAngle,
    required this.isFront,
  });

  // Map an ML Kit landmark → canvas offset
  Offset _toCanvas(PoseLandmark lm, Size canvas) {
    // ML Kit returns coordinates in the ROTATED (display) space.
    // imageSize already accounts for the rotation swap.
    double cx = (lm.x / imageSize.width)  * canvas.width;
    double cy = (lm.y / imageSize.height) * canvas.height;

    // CameraPreview mirrors front camera horizontally — match that.
    if (isFront) cx = canvas.width - cx;

    return Offset(cx, cy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pose == null || imageSize == Size.zero) return;

    final bonePaint = Paint()
      ..color       = const Color(0xFF00F0FF)
      ..strokeWidth = 2.5
      ..strokeCap   = StrokeCap.round
      ..style       = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFFFF007A)
      ..style = PaintingStyle.fill;

    final dotHighPaint = Paint()
      ..color = const Color(0xFF00FF66)
      ..style = PaintingStyle.fill;

    final ringPaint = Paint()
      ..color       = Colors.white54
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Bones
    for (final (ta, tb) in _kBones) {
      final a = pose!.landmarks[ta];
      final b = pose!.landmarks[tb];
      if (a == null || b == null)                         continue;
      if (a.likelihood < 0.3 || b.likelihood < 0.3)      continue;
      canvas.drawLine(_toCanvas(a, size), _toCanvas(b, size), bonePaint);
    }

    // Joints
    for (final lm in pose!.landmarks.values) {
      if (lm.likelihood < 0.3) continue;
      final pt = _toCanvas(lm, size);
      canvas.drawCircle(pt, 5, lm.likelihood > 0.7 ? dotHighPaint : dotPaint);
      canvas.drawCircle(pt, 5, ringPaint);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.pose != pose || old.imageSize != imageSize;
}

// ── Screen ──────────────────────────────────────────────────────────────────
class SignCameraScreen extends StatefulWidget {
  final String checkMode;
  const SignCameraScreen({super.key, required this.checkMode});

  @override
  State<SignCameraScreen> createState() => _SignCameraScreenState();
}

class _SignCameraScreenState extends State<SignCameraScreen> {
  CameraController?    _ctrl;
  CameraDescription?   _activeCam;
  List<CameraDescription>? _cameras;
  Interpreter?         _interp;
  PoseDetector?        _detector;
  List<String>         _labels     = [];
  List<double>         _scalerMean = [];
  List<double>         _scalerStd  = [];

  bool    _loading  = true;
  String? _initErr;
  bool    _busy     = false;

  String _prediction  = "AWAITING GESTURE...";
  Pose?  _pose;
  Size   _imageSize   = Size.zero;
  int    _sensorAngle = 90;

  // Diagnostic counters — shown on screen
  int _framesIn   = 0;
  int _posesFound = 0;

  final List<List<double>> _buf = [];
  static const int _seqLen      = 30;
  static const int _featCount   = 51;
  static const double _thresh   = 0.45;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // ── Initialisation ──────────────────────────────────────────────────────
  Future<void> _init() async {
    // Permission
    if (!(await Permission.camera.request()).isGranted) {
      if (mounted) setState(() {
        _initErr = "Camera permission denied.\nEnable in Settings → Apps.";
        _loading = false;
      });
      return;
    }

    // Pose detector
    try {
      _detector = PoseDetector(options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode:  PoseDetectionMode.stream,
      ));
    } catch (e) { debugPrint("Detector: $e"); }

    // TFLite
    try {
      if (widget.checkMode == "Sentences") {
        _interp = await Interpreter.fromAsset('assets/model/sign_language.tflite');
        final raw = await rootBundle.loadString('assets/model/labels.txt');
        _labels = raw.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
      } else {
        _interp = await Interpreter.fromAsset('assets/model/letter_classifier.tflite');
        final raw = await rootBundle.loadString('assets/model/letter_labels.txt');
        _labels = raw.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
        final js = json.decode(await rootBundle.loadString('assets/model/scaler_params.json'));
        _scalerMean = List<double>.from(js['mean']);
        _scalerStd  = List<double>.from(js['std']);
      }
      debugPrint("Model ready — ${_labels.length} labels");
    } catch (e) {
      debugPrint("Model: $e");
      if (mounted) setState(() => _prediction = "MODEL NOT LOADED");
    }

    // Camera — use NV21 for best ML Kit compatibility
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) throw Exception("No cameras");

      _activeCam = _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      _sensorAngle = _activeCam!.sensorOrientation;

      _ctrl = CameraController(
        _activeCam!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,   // ← NV21 for ML Kit
      );
      await _ctrl!.initialize();

      if (_detector != null) {
        await _ctrl!.startImageStream(_onFrame);
      }
    } catch (e) {
      debugPrint("Camera: $e");
      if (mounted) setState(() {
        _initErr = "Camera error: $e";
        _loading  = false;
      });
      return;
    }

    if (mounted) setState(() => _loading = false);
  }

  // ── Frame processing ────────────────────────────────────────────────────
  void _onFrame(CameraImage img) async {
    if (_busy) return;
    _busy = true;
    try {
      final inputImage = _makeInputImage(img);
      if (inputImage == null) return;

      final poses = await _detector!.processImage(inputImage);

      // After ML Kit processes a 640×480 image with 90° rotation,
      // it returns coordinates in the rotated portrait space (480×640).
      // For 0°/180° it stays landscape (640×480).
      final Size mlSize = (_sensorAngle == 90 || _sensorAngle == 270)
          ? Size(img.height.toDouble(), img.width.toDouble())
          : Size(img.width.toDouble(),  img.height.toDouble());

      if (mounted) {
        setState(() {
          _framesIn++;
          _pose      = poses.isNotEmpty ? poses.first : null;
          _imageSize = mlSize;
          if (poses.isNotEmpty) _posesFound++;
        });
      }

      if (_pose == null) return;

      // Build 51-feature landmark vector (normalised)
      List<double> frame = [];
      for (final t in [
        PoseLandmarkType.nose,
        PoseLandmarkType.leftEye,       PoseLandmarkType.rightEye,
        PoseLandmarkType.leftEar,       PoseLandmarkType.rightEar,
        PoseLandmarkType.leftShoulder,  PoseLandmarkType.rightShoulder,
        PoseLandmarkType.leftElbow,     PoseLandmarkType.rightElbow,
        PoseLandmarkType.leftWrist,     PoseLandmarkType.rightWrist,
        PoseLandmarkType.leftHip,       PoseLandmarkType.rightHip,
        PoseLandmarkType.leftKnee,      PoseLandmarkType.rightKnee,
        PoseLandmarkType.leftAnkle,     PoseLandmarkType.rightAnkle,
      ]) {
        final lm = _pose!.landmarks[t];
        if (lm != null) {
          frame.add(lm.x / mlSize.width);
          frame.add(lm.y / mlSize.height);
          frame.add(lm.likelihood);
        } else {
          frame.addAll([0.0, 0.0, 0.0]);
        }
      }
      if (frame.length != _featCount) frame = List.filled(_featCount, 0.0);

      if (widget.checkMode == "Alphabets") {
        _inferLetter(frame);
      } else {
        _buf.add(frame);
        if (_buf.length > _seqLen) _buf.removeAt(0);
        if (_buf.length == _seqLen) _inferWord();
      }
    } catch (e) {
      debugPrint("Frame: $e");
    } finally {
      _busy = false;
    }
  }

  // ── Inference ───────────────────────────────────────────────────────────
  void _inferLetter(List<double> lms) {
    if (_interp == null || _labels.isEmpty || _scalerMean.isEmpty) return;
    final keyIdxs = [0, 5, 6, 7, 8, 9, 10];
    List<double> feat = keyIdxs.map((i) => lms[i * 3]).toList();
    while (feat.length < 7) feat.add(0.0);
    feat = feat.sublist(0, 7);
    feat = List.generate(7, (i) =>
    _scalerStd[i] == 0 ? 0.0 : (feat[i] - _scalerMean[i]) / _scalerStd[i]);
    var out = [List<double>.filled(_labels.length, 0.0)];
    _interp!.run([feat], out);
    final scores = out[0];
    final max = scores.reduce((a,b) => a>b ? a : b);
    final idx = scores.indexOf(max);
    if (mounted && max >= _thresh) setState(() => _prediction = _labels[idx]);
  }

  void _inferWord() {
    if (_interp == null || _labels.isEmpty) return;
    var out = [List<double>.filled(_labels.length, 0.0)];
    _interp!.run([List<List<double>>.from(_buf)], out);
    final scores = out[0];
    final max = scores.reduce((a,b) => a>b ? a : b);
    final idx = scores.indexOf(max);
    if (mounted && max >= _thresh) setState(() => _prediction = _labels[idx].toUpperCase());
  }

  // ── Image conversion — NV21 single plane ────────────────────────────────
  InputImage? _makeInputImage(CameraImage img) {
    if (_activeCam == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(_sensorAngle);
    if (rotation == null) return null;

    // NV21: all data in planes[0]
    final Uint8List bytes = img.planes[0].bytes;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size:        Size(img.width.toDouble(), img.height.toDouble()),
        rotation:    rotation,
        format:      InputImageFormat.nv21,
        bytesPerRow: img.planes[0].bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl?.stopImageStream();
    _ctrl?.dispose();
    _detector?.close();
    _interp?.close();
    super.dispose();
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_loading && _initErr != null) {
      return Scaffold(
        appBar: AppBar(title: Text("HUD: ${widget.checkMode.toUpperCase()}")),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_initErr!, textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 16)),
        )),
      );
    }
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_ctrl == null || !_ctrl!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text("HUD: ${widget.checkMode.toUpperCase()}")),
        body: const Center(child: Text("Camera not ready.",
            style: TextStyle(color: Colors.white54))),
      );
    }

    final isFront = _activeCam?.lensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        title: Text("${widget.checkMode.toUpperCase()} RECOGNITION"),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: SafeArea(child: Column(children: [

        // ── Camera + skeleton ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.primary, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(fit: StackFit.expand, children: [

                CameraPreview(_ctrl!),

                // Skeleton overlay
                CustomPaint(
                  painter: _SkeletonPainter(
                    pose:        _pose,
                    imageSize:   _imageSize,
                    sensorAngle: _sensorAngle,
                    isFront:     isFront,
                  ),
                ),

                // ── Diagnostic strip (top) ───────────────────────────
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Text(
                      "Frames: $_framesIn  |  Poses: $_posesFound  |  "
                          "Size: ${_imageSize.width.toInt()}×${_imageSize.height.toInt()}  |  "
                          "Sensor: ${_sensorAngle}°",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),

                // Mode badge
                Positioned(
                  bottom: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isFront ? "FRONT  ${_sensorAngle}°" : "BACK  ${_sensorAngle}°",
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Progress bar (word mode)
                if (widget.checkMode == "Sentences")
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: LinearProgressIndicator(
                      value: _buf.length / _seqLen,
                      backgroundColor: Colors.white12,
                      color: theme.colorScheme.primary,
                      minHeight: 3,
                    ),
                  ),
              ]),
            ),
          ),
        ),

        // ── Prediction panel ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.checkMode == "Sentences" ? "PSL WORD" : "LETTER",
                    style: const TextStyle(color: Colors.white38, fontSize: 10,
                        fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _prediction,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context, _prediction.toLowerCase()),
                icon: const Icon(Icons.send_and_archive, size: 18),
                label: const Text("USE", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        ),
      ])),
    );
  }
}