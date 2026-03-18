import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class VoskService {
  static final VoskService instance = VoskService._();
  VoskService._();

  Model? _model;
  VoskFlutterPlugin? _vosk;

  bool get isReady => _model != null;

  Future<void> init() async {
    if (_vosk != null) return;

    // Ensure mic permissions before attempting to use Vosk later
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }

    _vosk = VoskFlutterPlugin.instance();
    final modelPath = await _getOrDownloadModel();
    _model = await _vosk!.createModel(modelPath);
  }

  Future<Recognizer> createRecognizer() async {
    if (_model == null) throw Exception('Vosk model not initialized.');
    return await _vosk!.createRecognizer(model: _model!, sampleRate: 16000);
  }

  Future<SpeechService> initSpeechService(Recognizer recognizer) async {
    if (_vosk == null) throw Exception('Vosk not initialized.');
    return await _vosk!.initSpeechService(recognizer);
  }

  Future<String> _getOrDownloadModel() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/vosk-model-small-ar-0.3');
    
    if (await modelDir.exists()) {
      return modelDir.path;
    }
    
    debugPrint('[VoskService] Downloading Arabic model (approx. 36MB)...');
    final url = 'https://alphacephei.com/vosk/models/vosk-model-small-ar-0.3.zip';
    final response = await http.get(Uri.parse(url));
    
    debugPrint('[VoskService] Download complete. Extracting...');
    final bytes = response.bodyBytes;
    final archive = ZipDecoder().decodeBytes(bytes);
    
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final f = File('${dir.path}/$filename');
        await f.create(recursive: true);
        await f.writeAsBytes(data);
      } else {
        await Directory('${dir.path}/$filename').create(recursive: true);
      }
    }
    debugPrint('[VoskService] Extraction complete.');
    return modelDir.path;
  }
}
