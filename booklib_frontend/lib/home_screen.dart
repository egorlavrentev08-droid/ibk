import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _books = [];
  bool _loading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadBooks();
  }
  
  Future<void> _loadBooks() async {
    setState(() => _loading = true);
    try {
      final books = await ApiService.getBooks();
      setState(() {
        _books = books;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Библиотека'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => authProvider.logout(),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _books.isEmpty
                  ? Center(child: Text('Книг пока нет'))
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _books.length,
                      itemBuilder: (context, index) {
                        final book = _books[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            leading: Icon(Icons.book, size: 40),
                            title: Text(
                              book['title'],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(book['description'] ?? ''),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () {
                              // TODO: Открыть экран книги
                            },
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Создать книгу
        },
        child: Icon(Icons.add),
      ),
    );
  }
}