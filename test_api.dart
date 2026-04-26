import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final authHeader = "c0957e34a11786192e8819a7d4faef725c3a0becf05716823b30e37111196e92ba1953a695dddd761cce8abbffefce40da8059d06aa651a02f9cc3322a7d1e0b";
  
  print("Getting auth...");
  final authRes = await http.post(Uri.parse("https://ai.elliottwen.info/auth"), headers: {"Authorization": authHeader});
  
  final data = jsonDecode(authRes.body);
  final sig = data['signature'];
  print("Sig: $sig");
  
  print("Getting image...");
  final imgRes = await http.post(
    Uri.parse("https://ai.elliottwen.info/generate_image"),
    headers: {"Authorization": authHeader, "Content-Type": "application/json"},
    body: jsonEncode({"signature": sig, "prompt": "test image"})
  );
  
  print("Content-Type: ${imgRes.headers['content-type']}");
  final bodyStr = imgRes.body;
  if (bodyStr.length > 200) {
    print("Body starts with: ${bodyStr.substring(0, 200)}");
  } else {
    print("Body: $bodyStr");
  }
}
