import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateBookScreen extends StatefulWidget {
  @override
  _CreateBookScreenState createState() => _CreateBookScreenState();
}

class _CreateBookScreenState extends State<CreateBookScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isRestricted = false;
  bool _loading = false;
  String? _error;
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _createBook() async {
    if (_titleController.text.isEmpty) {
      setState(() => _error = 'Введите название книги');
      return;
    }
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      await ApiService.createBook(
        _titleController.text,
        _descriptionController.text,
        isRestricted: _isRestricted,
      );
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Новая книга'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Название книги',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text('Ограниченная книга'),
              subtitle: Text('Запрещает копирование и скриншоты'),
              value: _isRestricted,
              onChanged: (value) => setState(() => _isRestricted = value),
            ),
            if (_error != null) ...[
              SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.red)),
            ],
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _createBook,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: _loading
                  ? CircularProgressIndicator()
                  : Text('Создать книгу'),
            ),
          ],
        ),
      ),
    );
  }
}