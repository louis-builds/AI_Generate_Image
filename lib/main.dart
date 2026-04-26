import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Image Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '✨ AI Image Generator'),
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
  final TextEditingController _controller = TextEditingController();
  final String _authHeader = "c0957e34a11786192e8819a7d4faef725c3a0becf05716823b30e37111196e92ba1953a695dddd761cce8abbffefce40da8059d06aa651a02f9cc3322a7d1e0b";
  
  String? _signature;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _errorMessage;
  http.Client? _client;

  Future<void> _generateImage() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isLoading = true;
      _signature = null;
      _errorMessage = null;
    });

    _client = http.Client();

    try {
      debugPrint("Fetching Signature...");
      final authResponse = await _client!.post(
        Uri.parse("https://ai.elliottwen.info/auth"),
        headers: {"Authorization": _authHeader},
      );

      debugPrint("Auth Status: ${authResponse.statusCode}");

      if (authResponse.statusCode != 200) {
        throw "Auth failed: ${authResponse.statusCode}";
      }

      String parsedSignature;
      try {
        final data = jsonDecode(authResponse.body);
        parsedSignature = data['signature'] ?? authResponse.body;
      } catch (_) {
        parsedSignature = authResponse.body;
      }
      
      debugPrint("Parsed Signature: $parsedSignature");

      debugPrint("Calling /generate_image...");
      final imageResponse = await _client!.post(
        Uri.parse("https://ai.elliottwen.info/generate_image"),
        headers: {
          "Authorization": _authHeader,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "signature": parsedSignature,
          "prompt": prompt,
        }),
      );

      debugPrint("Generate Image Status: ${imageResponse.statusCode}");

      if (imageResponse.statusCode != 200) {
        throw "Generation failed: ${imageResponse.statusCode}\n${imageResponse.body}";
      }

      // The server returns a JSON string containing the relative path to the image
      final imagePath = jsonDecode(imageResponse.body) as String;
      final imageUrl = "https://ai.elliottwen.info/$imagePath";
      
      debugPrint("Image URL: $imageUrl");

      // Now we fetch the actual image bytes
      final actualImageResponse = await _client!.get(Uri.parse(imageUrl));

      if (actualImageResponse.statusCode != 200) {
        throw "Failed to download image bytes: ${actualImageResponse.statusCode}";
      }

      setState(() {
        _imageBytes = actualImageResponse.bodyBytes;
        _signature = null; // Hide the signature text in UI
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error: $e";
      });
    } finally {
      _client?.close();
      _client = null;
    }
  }

  void _stopWaiting() {
    _client?.close();
    _client = null;
    setState(() {
      _isLoading = false;
      _errorMessage = "Request stopped by user.";
    });
  }

  Future<void> _saveImage() async {
    if (_imageBytes == null) return;

    try {
      // On Android 13+, Permission.storage is deprecated and always denied.
      // Saving to the gallery via MediaStore does NOT require this permission on modern Android.
      final result = await ImageGallerySaverPlus.saveImage(_imageBytes!);
      
      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Success! Image saved to gallery.")),
        );
      } else {
        // If it fails, it might be an older Android needing permission
        var status = await Permission.storage.request();
        if (status.isGranted) {
           final retryResult = await ImageGallerySaverPlus.saveImage(_imageBytes!);
           if (retryResult['isSuccess'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Success! Image saved to gallery.")),
              );
              return;
           }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Save failed. Please check permissions.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during save: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter your image prompt',
                hintText: 'e.g., A futuristic cyberpunk city',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _generateImage,
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text("Generate Image"),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
                if (_isLoading) ...[
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _stopWaiting,
                    icon: const Icon(Icons.stop),
                    label: const Text("Stop"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 30),
            Container(
              height: 400,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: _isLoading
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text("AI is generating your image..."),
                        ],
                      )
                    : _signature != null
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SingleChildScrollView(
                              child: Text(
                                "Digital Signature Received:\n\n$_signature",
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              _errorMessage ?? "Your generated image will appear here",
                              style: TextStyle(color: _errorMessage != null ? Colors.red : Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 20),
            if (_imageBytes != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveImage,
                  icon: const Icon(Icons.save_alt),
                  label: const Text("Save to Local Album"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.green.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}