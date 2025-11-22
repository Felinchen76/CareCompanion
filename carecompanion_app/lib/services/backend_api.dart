import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class BackendApi {
  final Uri baseUri;
  BackendApi({required this.baseUri});

  Future<Map<String, dynamic>> analyzeFile(Uint8List bytes, String filename) async {
    final uri = baseUri.replace(path: '/api/extract');
    final req = http.MultipartRequest('POST', uri);
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) throw Exception('Backend error ${res.statusCode}: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> analyzeText(String text) async {
    final uri = baseUri.replace(path: '/api/extract');
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'text': text}));
    if (res.statusCode != 200) throw Exception('Backend error ${res.statusCode}: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}