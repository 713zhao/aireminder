import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'settings_service.dart';

class GeminiService {
  static String get _baseUrl {
    final model = SettingsService.aiModel;
    return 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
  }
  
  /// Compress image if it's too large
  static Uint8List _compressImage(Uint8List imageBytes, {int maxSizeKB = 512}) {
    try {
      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        print('Failed to decode image, using original');
        return imageBytes;
      }
      
      print('Original image: ${image.width}x${image.height}');
      
      // Calculate compression ratio based on current size
      final currentSizeKB = imageBytes.length / 1024;
      print('Current size: ${currentSizeKB.toStringAsFixed(0)} KB');
      
      if (currentSizeKB <= maxSizeKB) {
        print('Image already small enough');
        return imageBytes;
      }
      
      // Calculate target dimensions to achieve target size
      final compressionRatio = maxSizeKB / currentSizeKB;
      final scaleFactor = (compressionRatio * 0.8).clamp(0.1, 1.0); // 0.8 for safety margin
      
      final newWidth = (image.width * scaleFactor).round();
      final newHeight = (image.height * scaleFactor).round();
      
      print('Compressing to: ${newWidth}x${newHeight} (scale: ${(scaleFactor * 100).toStringAsFixed(1)}%)');
      
      // Resize the image
      final resized = img.copyResize(image, width: newWidth, height: newHeight);
      
      // Encode as JPEG with quality adjustment
      int quality = 85;
      Uint8List compressed;
      
      do {
        compressed = img.encodeJpg(resized, quality: quality);
        final compressedSizeKB = compressed.length / 1024;
        print('Compressed size at quality $quality: ${compressedSizeKB.toStringAsFixed(0)} KB');
        
        if (compressedSizeKB <= maxSizeKB || quality <= 30) {
          break;
        }
        
        quality -= 10;
      } while (quality > 30);
      
      final finalSizeKB = compressed.length / 1024;
      print('Final compressed size: ${finalSizeKB.toStringAsFixed(0)} KB');
      
      return compressed;
    } catch (e) {
      print('Compression failed: $e, using original image');
      return imageBytes;
    }
  }
  
  /// Extract event information from an image using Gemini API
  static Future<Map<String, dynamic>?> extractEventFromImage(dynamic imageSource) async {
    // Check if AI provider is Gemini and get appropriate API key
    final aiProvider = SettingsService.aiProvider;
    if (aiProvider != 'gemini') {
      throw Exception('Current AI provider ($aiProvider) does not support image analysis. Please switch to Google Gemini in Settings.');
    }
    
    final apiKey = SettingsService.aiApiKey.isNotEmpty 
        ? SettingsService.aiApiKey 
        : SettingsService.geminiApiKey; // Fallback for backwards compatibility
        
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured. Please set it in Settings.');
    }
    
    // Read and encode the image - handle both File and XFile
    Uint8List imageBytes;
    String fileName;
    
    if (imageSource is XFile) {
      // Web or cross-platform XFile
      imageBytes = await imageSource.readAsBytes();
      fileName = imageSource.name.toLowerCase();
    } else if (imageSource is File) {
      // Mobile File
      if (!imageSource.existsSync()) {
        throw Exception('Image file does not exist');
      }
      imageBytes = imageSource.readAsBytesSync();
      fileName = imageSource.path.toLowerCase();
    } else {
      throw Exception('Unsupported image source type');
    }
    
    // Check and compress image if needed
    final originalSizeKB = imageBytes.length / 1024;
    print('Original image size: ${originalSizeKB.toStringAsFixed(0)} KB');
    
    if (originalSizeKB > 512) { // 512KB
      print('Image too large, compressing...');
      imageBytes = _compressImage(imageBytes, maxSizeKB: 512);
      
      final compressedSizeKB = imageBytes.length / 1024;
      print('Compressed from ${originalSizeKB.toStringAsFixed(0)} KB to ${compressedSizeKB.toStringAsFixed(0)} KB');
    }
    
    final base64Image = base64Encode(imageBytes);
    print('Base64 length: ${base64Image.length} characters');
    
    // Simple MIME type detection
    String mimeType = 'image/jpeg';
    if (fileName.endsWith('.png') && originalSizeKB <= 512) {
      // Keep PNG only if it wasn't compressed
      mimeType = 'image/png';
    } else if (fileName.endsWith('.gif') && originalSizeKB <= 512) {
      mimeType = 'image/gif';
    } else if (fileName.endsWith('.webp') && originalSizeKB <= 512) {
      mimeType = 'image/webp';
    }
    // Note: Compressed images are always JPEG
    
    final url = Uri.parse('$_baseUrl?key=$apiKey');
    
    // Use different HTTP clients for web vs mobile
    Map<String, dynamic> responseData;
    
    if (kIsWeb) {
      // Use http package for web
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [
              {
                'text': 'Extract event from image. Return JSON: {"title":"","date":"YYYY-MM-DD","time":"HH:MM","location":"","description":"","recurrence":{"type":"none"},"confidence":"medium"}. If no event: {"error":"No event"}'
              },
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Image
                }
              }
            ]
          }],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 2048,
            'topP': 0.95,
            'topK': 40
          }
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
      
      // Debug: Log the raw response
      print('Raw API Response: ${response.body}');
      
      responseData = jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      // Use HttpClient for mobile
      final client = HttpClient();
      try {
        final request = await client.postUrl(url);
        request.headers.set('Content-Type', 'application/json');
        
        final bodyString = jsonEncode({
          'contents': [{
            'parts': [
              {
                'text': 'Extract event from image. Return JSON: {"title":"","date":"YYYY-MM-DD","time":"HH:MM","location":"","description":"","recurrence":{"type":"none"},"confidence":"medium"}. If no event: {"error":"No event"}'
              },
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Image
                }
              }
            ]
          }],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 2048,
            'topP': 0.95,
            'topK': 40
          }
        });
        
        request.write(bodyString);
        
        final response = await request.close();
        
        if (response.statusCode != 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          throw Exception('API Error ${response.statusCode}: $responseBody');
        }
        
        final responseBody = await response.transform(utf8.decoder).join();
        
        // Debug: Log the raw response
        print('Raw API Response: $responseBody');
        
        responseData = jsonDecode(responseBody) as Map<String, dynamic>;
      } finally {
        client.close();
      }
    }
    
    final candidates = responseData['candidates'] as List?;
    
    if (candidates == null || candidates.isEmpty) {
      // Debug: Log the full response to understand the structure
      throw Exception('No response from AI. Full response: ${jsonEncode(responseData)}');
    }
    
    final candidate = candidates[0];
    if (candidate == null) {
      throw Exception('First candidate is null. Full response: ${jsonEncode(responseData)}');
    }
    
    final content = candidate['content'];
    if (content == null) {
      throw Exception('Content is null. Candidate: ${jsonEncode(candidate)}');
    }
    
    final parts = content['parts'] as List?;
    
    if (parts == null || parts.isEmpty) {
      // Check if there's a finish reason that explains the issue
      final finishReason = candidate['finishReason'];
      throw Exception('Parts is null or empty. Content: ${jsonEncode(content)}. FinishReason: $finishReason. Full candidate: ${jsonEncode(candidate)}');
    }
    
    final firstPart = parts[0];
    if (firstPart == null || firstPart['text'] == null) {
      throw Exception('First part or text is null. Parts: ${jsonEncode(parts)}');
    }
    
    final textResponse = firstPart['text'] as String;
    
    // Try to extract JSON from response
    final jsonRegex = RegExp(r'\{.*\}', dotAll: true);
    final match = jsonRegex.firstMatch(textResponse);
    
    if (match != null) {
      try {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      } catch (e) {
        // Return error with raw response
        return {
          'error': 'Failed to parse JSON response',
          'raw_response': textResponse
        };
      }
    } else {
      return {
        'error': 'No JSON found in response',
        'raw_response': textResponse
      };
    }
  }
  
  /// Parse extracted date and time into DateTime object
  /// If only date provided → use current time
  /// If only time provided → use current date
  /// If neither provided → use current date and time
  static DateTime? parseDateTime(String? dateStr, String? timeStr) {
    final now = DateTime.now();
    
    // Handle different scenarios
    final hasDate = dateStr != null && dateStr.isNotEmpty && dateStr != 'null';
    final hasTime = timeStr != null && timeStr.isNotEmpty && timeStr != 'null';
    
    // If neither date nor time, return current date and time
    if (!hasDate && !hasTime) {
      print('No date or time provided, using current: ${now.toString()}');
      return now;
    }
    
    try {
      int year = now.year;
      int month = now.month;
      int day = now.day;
      int hour = now.hour;
      int minute = now.minute;
      
      // Parse date if provided
      if (hasDate) {
        final dateParts = dateStr.split('-');
        if (dateParts.length == 3) {
          year = int.parse(dateParts[0]);
          month = int.parse(dateParts[1]);
          day = int.parse(dateParts[2]);
        } else {
          print('Invalid date format: $dateStr, using current date');
        }
      } else {
        print('No date provided, using current date: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
      }
      
      // Parse time if provided
      if (hasTime) {
        final timeParts = timeStr.split(':');
        if (timeParts.length >= 2) {
          hour = int.parse(timeParts[0]);
          minute = int.parse(timeParts[1]);
        } else {
          print('Invalid time format: $timeStr, using current time');
        }
      } else {
        print('No time provided, using current time: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
      }
      
      final result = DateTime(year, month, day, hour, minute);
      print('Parsed DateTime: ${result.toString()}');
      return result;
      
    } catch (e) {
      print('Error parsing date/time: $e, falling back to current time');
      return now;
    }
  }
}