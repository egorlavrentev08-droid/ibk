import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  String? _coverImageUrl;
  String? _coverImageName;
  bool _uploadingCover = false;
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _pickCover() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Важно для Web — получаем байты
      );
      
      if (result != null && result.files.isNotEmpty) {
        setState(() => _uploadingCover = true);
        final file = result.files.first;
        
        if (file.bytes != null && file.name != null) {
          // Web — используем байты
          final uploadResult = await ApiService.uploadImage(
            '',
            bytes: file.bytes,
            fileName: file.name,
          );
          setState(() {
            _coverImageUrl = uploadResult['url'];
            _coverImageName = uploadResult['filename'];
            _uploadingCover = false;
          });
        } else if (file.path != null) {
          // Desktop — используем путь
          final uploadResult = await ApiService.uploadImage(file.path!);
          setState(() {
            _coverImageUrl = uploadResult['url'];
            _coverImageName = uploadResult['filename'];
            _uploadingCover = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _uploadingCover = false;
      });
    }
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
        coverImage: _coverImageUrl,
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
            // Загрузка обложки
            Center(
              child: GestureDetector(
                onTap: _uploadingCover ? null : _pickCover,
                child: Container(
                  width: 150,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: _uploadingCover
                      ? Center(child: CircularProgressIndicator())
                      : _coverImageUrl != null
                          ? Image.network(
                              '${ApiService.baseUrl}${_coverImageUrl}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.broken_image, size: 48, color: Colors.grey);
                              },
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Загрузить обложку', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                ),
              ),
            ),
            SizedBox(height: 24),
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