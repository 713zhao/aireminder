import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

class GeminiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  
  /// Extract event information from an image using Gemini API
  static Future<Map<String, dynamic>?> extractEventFromImage(File imageFile) async {
    final apiKey = SettingsService.geminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured. Please set it in Settings.');
    }
    
    try {
      // Read and encode the image
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);
      
      // Prepare the request
      final url = Uri.parse('$_baseUrl?key=$apiKey');
      
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": """Please analyze this image and extract any event/appointment/reminder information you can find. Look for:
- Event title/name
- Date and time information
- Location/venue
- Description or notes
- Duration
- Any other relevant details

Return the information in JSON format with these fields (use null for missing information):
{
  "title": "event title",
  "date": "YYYY-MM-DD format if found",
  "time": "HH:MM format if found", 
  "location": "location if found",
  "description": "any additional notes or description",
  "duration": "duration in minutes if found",
  "confidence": "high/medium/low based on how clear the information is"
}

If no event information is found, return {"error": "No event information found in the image"}"""
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.1,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 1024,
        }
      };
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['candidates'] != null && 
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          
          final textResponse = responseData['candidates'][0]['content']['parts'][0]['text'] as String;
          
          // Try to extract JSON from the response
          final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(textResponse);
          if (jsonMatch != null) {
            final jsonString = jsonMatch.group(0)!;
            final extractedData = jsonDecode(jsonString) as Map<String, dynamic>;
            return extractedData;
          }
        }
        
        throw Exception('Unexpected response format from Gemini API');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Gemini API Error: ${errorData['error']['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to process image: $e');
    }
  }
  
  /// Parse extracted date and time into DateTime object
  static DateTime? parseDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null) return null;
    
    try {
      // Parse date
      final dateParts = dateStr.split('-');
      if (dateParts.length != 3) return null;
      
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      
      // Parse time if available
      int hour = 0;
      int minute = 0;
      
      if (timeStr != null && timeStr.isNotEmpty) {
        final timeParts = timeStr.split(':');
        if (timeParts.length >= 2) {
          hour = int.parse(timeParts[0]);
          minute = int.parse(timeParts[1]);
        }
      }
      
      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      return null;
    }
  }
}