import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool isLoading = true;
  bool isAuthenticated = false;
  String? username;
  String? rank;
  
  AuthProvider() {
    checkAuth();
  }
  
  Future<void> checkAuth() async {
    isLoading = true;
    notifyListeners();
    
    final token = await ApiService.getToken();
    if (token != null) {
      isAuthenticated = true;
    }
    
    isLoading = false;
    notifyListeners();
  }
  
  Future<void> login(String username, String password) async {
    try {
      final data = await ApiService.login(username, password);
      this.username = data['username'];
      this.rank = data['rank'];
      isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> register(String username, String password) async {
    try {
      final data = await ApiService.register(username, password);
      this.username = data['username'];
      this.rank = data['rank'];
      isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> logout() async {
    await ApiService.deleteToken();
    isAuthenticated = false;
    username = null;
    rank = null;
    notifyListeners();
  }
}  
