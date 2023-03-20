import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({Key? key}) : super(key: key);

  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  bool _isBusy = false;

  CameraController? _controller;
  late List<CameraDescription> cameraList;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
    ),
  );
  Future<void> init() async {
    cameraList = await availableCameras();
    _controller = CameraController(cameraList[1], ResolutionPreset.high);

    _controller!.initialize().then((value) {
      _controller!.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _controller!.dispose();
    super.dispose();
  }

  List<String> directions = [];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _controller?.value.isInitialized == true
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(400),
                    child: SizedBox(
                      width: 400,
                      height: 400,
                      child: CameraPreview(
                        _controller!,
                      ),
                    ),
                  )
                : const SizedBox(),
            const SizedBox(
              height: 20,
            ),
            Column(
              children: directions.map((e) => Text(e)).toList(),
            )
          ],
        ),
      ),
    );
  }

  Future _processCameraImage(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    final camera = cameraList[1];
    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (imageRotation == null) return;

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw);
    if (inputImageFormat == null) return;

    final planeData = image.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    final inputImage =
        InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

    processImage(inputImage);
  }

  Future<void> processImage(InputImage inputImage) async {
    if (_isBusy) return;
    _isBusy = true;

    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isNotEmpty) {
      if ((faces.first.headEulerAngleY ?? 0) >= 45) {
        if (directions.length == 3) {
          directions[2] = 'right';
        } else {
          directions.add('right');
        }
      } else if ((faces.first.headEulerAngleY ?? 0) <= -45) {
        if (directions.length == 3) {
          directions[2] = 'left';
        } else {
          directions.add("left");
        }
      } else if ((faces.first.headEulerAngleY ?? 0) <= 0 &&
          (faces.first.headEulerAngleY ?? 0) < 10) {
        if (directions.length == 3) {
          directions[2] = 'center';
        } else {
          directions.add("center");
        }
      }
    }

    _isBusy = false;

    if (mounted) {
      setState(() {});
    }
  }
}
