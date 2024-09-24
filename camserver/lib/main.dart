//import 'dart:ui_web';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/io.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Camera Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController? _controller;
  bool _isRecording = false;
  late Timer _timer;
  late IOWebSocketChannel _channel;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initializeCamera();
    // _initializeWebSocket();
  }

  Future<void> _initializeCamera() async {
    // Request permissions
    await _requestPermissions();

    final cameras = await availableCameras();
    final camera = cameras.first;

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
    );

    await _controller!.initialize();
    setState(() {});
  }

  //0825
  Future<void> _initializeWebSocket() async {
    _channel = IOWebSocketChannel.connect('ws://192.168.50.144:1125');
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
      Permission.manageExternalStorage
    ].request();
  }

  void _startRecording() async {
    _initializeWebSocket();
    /*
    _channel.stream.listen((message) {
      print('Received message: $message');
    });
    */
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    await _controller?.startVideoRecording();

    setState(() {
      _isRecording = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 29), (timer) async {
      await _stopRecording();
      _startRecording();
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    final XFile? video = await _controller?.stopVideoRecording();

    /*0907
    final String? videoPath = video?.path;
    final String? videoName = video?.name;
    _sendVideoToServer(videoPath!);
    String newPath = '/storage/emulated/0/Movies/MyAppVideos';


    final Directory dir = Directory(newPath);

    String newVideoPath = '${dir.path}/$videoName';

     */

    //print(videoPath);

    setState(() {
      _isRecording = false;
    });

    _timer.cancel();

    /*0907
    if (videoPath != null) {
      // 保存视频到相册
      final bool? saved = await GallerySaver.saveVideo(videoPath, albumName: 'MyAppVideos');
      if (saved == true) {
        print('Video saved to gallery: $newVideoPath');
        print(newVideoPath);

      } else {
        print('Failed to save video to gallery');
      }
    } else {
      print('未錄製任何影片');
    }
     */

    if (video != null) {
      // 直接使用 XFile 对象传送视频数据到 WebSocket 服务器
      await _sendVideoToServer(video);
    } else {
      print('未錄製任何影片');
    }
  }

  /*
  // 每一段chunkSize傳一段影片
  Future<void> _sendVideoToServer(String videoPath) async {
    const int chunkSize = 1 * 1024 * 1024; // 1 MB chunk size
    try {
      final videoFile = File(videoPath);
      final videoLength = await videoFile.length();
      int offset = 0;

      while (offset < videoLength) {
        final end = (offset + chunkSize > videoLength) ? videoLength : offset + chunkSize;
        final videoChunk = await videoFile.openRead(offset, end).toList();
        final videoBytes = videoChunk.expand((element) => element).toList();
        _channel.sink.add(videoBytes);
        offset = end;
      }

      String endOfFile = 'EOF';
      _channel.sink.add(endOfFile);
      print('Video sent to server in chunks');
    } catch (e) {
      print('Failed to send video to server: $e');
    }
  }
   */

  //0907
  Future<void> _sendVideoToServer(XFile video) async {
    //const int chunkSize = 1 * 1024 * 1024; // 1 MB chunk size

    /*
    try {
      final videoFile = video;
      final videoBytes = await videoFile.readAsBytes();

      // 分塊傳
      const int chunkSize = 1024 * 1024; // 每塊1MB
      for (int i = 0; i < videoBytes.length; i += chunkSize) {
        int end = (i + chunkSize < videoBytes.length) ? i + chunkSize : videoBytes.length;
        _channel.sink.add(videoBytes.sublist(i, end));
        _channel.sink.add("hello");
        //await Future.delayed(const Duration(milliseconds: 100)); // 等待以防止緩衝區溢出
      }

      _channel.sink.add("EOF");
      print('Video sent to server');
    } catch (e) {
      print('Failed to send video to server: $e');
    }

     */

    try {
      final videoStream = video.openRead();
      final videoLength = await video.length();
      int offset = 0;

      await for (var chunk in videoStream) {
        //print(chunk.length);
        final end = (offset + chunk.length > videoLength)
            ? videoLength
            : offset + chunk.length;
        final videoBytes = chunk.sublist(0, end - offset);
        _channel.sink.add(videoBytes);
        offset = end;

        // 如果需要每次发送后延迟一会儿以避免缓冲区溢出，可以取消注释下面的行
        //await Future.delayed(const Duration(milliseconds: 5000));
      }

      String endOfFile = 'EOF';
      _channel.sink.add(endOfFile);
      //await _channel.sink.done;
      print('Video sent to server in chunks');
      _channel.stream.listen((message) async {
        print('Received message: $message');
        // 在這裡處理來自 Server 的訊息
        if (message == "yes") {
          // 获取视频文件的路径
          final String videoPath = video.path;

          // 保存视频到相册
          final bool? saved = await GallerySaver.saveVideo(videoPath, albumName: 'MyAppVideos');
          if (saved == true) {
            print('Video saved to gallery: $videoPath');
          } else {
            print('Failed to save video to gallery');
          }

          _channel.sink.close();
        }
        else{
          _channel.sink.close();
        }
      });
    } catch (e) {
      print('Failed to send video to server: $e');
    }
  }
  // await!!!!!!!!!!!!

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_controller != null && _controller!.value.isInitialized)
                CameraPreview(_controller!)
              else
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 30.0, // 调整位置
            left: MediaQuery.of(context).size.width / 2 - 13, // 編輯水平位置
            child: FloatingActionButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              tooltip: 'Record',
              child: Icon(_isRecording ? Icons.stop : Icons.videocam),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer.cancel();
    super.dispose();
  }
}
