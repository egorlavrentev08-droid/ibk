import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';
  
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
  
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }
  
  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }
  
  static Future<Map<String, dynamic>> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['access_token']);
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Ошибка регистрации');
    }
  }
  
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['access_token']);
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Ошибка входа');
    }
  }
  
  static Future<List<dynamic>> getBooks() async {
    final response = await http.get(
      Uri.parse('$baseUrl/books/'),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Ошибка получения книг');
    }
  }
  
  static Future<Map<String, dynamic>> getBook(int bookId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/books/$bookId'),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Ошибка получения книги');
    }
  }
  
  static Future<Map<String, dynamic>> createBook(
    String title,
    String description, {
    bool isRestricted = false,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/books/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'is_restricted': isRestricted,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Ошибка создания книги');
    }
  }
  
  static Future<List<dynamic>> getChapters(int bookId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chapters/book/$bookId'),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Ошибка получения глав');
    }
  }
  
  static Future<Map<String, dynamic>> createChapter(
    int bookId,
    String title,
    String content, {
    int orderNumber = 1,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/chapters/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'book_id': bookId,
        'title': title,
        'content': content,
        'order_number': orderNumber,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Ошибка создания главы');
    }
  }
  
  static Future<Map<String, dynamic>> createRating(
    int bookId,
    int stars, {
    String? review,
    bool isAnonymous = false,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/ratings/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'book_id': bookId,
        'stars': stars,
        'review': review,
        'is_anonymous': isAnonymous,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Ошибка создания оценки');
    }
  }
  
  static Future<Map<String, dynamic>> updateRating(
    int ratingId, {
    int? stars,
    String? review,
    bool? isAnonymous,
  }) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/ratings/$ratingId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (stars != null) 'stars': stars,
        if (review != null) 'review': review,
        if (isAnonymous != null) 'is_anonymous': isAnonymous,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Ошибка обновления оценки');
    }
  }
  
  static Future<Map<String, dynamic>> getAverageRating(int bookId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ratings/book/$bookId/average'),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {'average': 0, 'count': 0};
    }
  }
  
  static Future<List<dynamic>> getBookReviews(int bookId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ratings/book/$bookId/reviews'),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Ошибка получения отзывов');
    }
  }
  
  static Future<Map<String, dynamic>> voteReview(int ratingId, String voteType) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/ratings/$ratingId/vote?vote_type=$voteType'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Ошибка голосования');
    }
  }
}