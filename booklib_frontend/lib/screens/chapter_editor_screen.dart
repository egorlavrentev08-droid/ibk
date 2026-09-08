import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/api_service.dart';

class ChapterEditorScreen extends StatefulWidget {
  final int bookId;
  final int? chapterId; // Если редактируем существующую главу
  final Map<String, dynamic>? chapter; // Данные главы для редактирования
  
  ChapterEditorScreen({
    required this.bookId,
    this.chapterId,
    this.chapter,
  });
  
  @override
  _ChapterEditorScreenState createState() => _ChapterEditorScreenState();
}

class _ChapterEditorScreenState extends State<ChapterEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _orderController = TextEditingController(text: '1');
  
  String? _backgroundImageUrl;
  String? _backgroundImageName;
  bool _uploadingBackground = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  int _wordCount = 0;
  int _readTime = 0;
  Timer? _autosaveTimer;
  bool _isPreview = false;
  
  @override
  void initState() {
    super.initState();
    
    // Если редактируем существующую главу
    if (widget.chapter != null) {
      _titleController.text = widget.chapter!['title'] ?? '';
      _contentController.text = widget.chapter!['content'] ?? '';
      _orderController.text = '${widget.chapter!['order_number'] ?? 1}';
      _backgroundImageUrl = widget.chapter!['background_image'];
      _updateWordCount();
    } else {
      _loadDraft();
    }
    
    // Слушаем изменения текста для автосохранения
    _contentController.addListener(_onContentChanged);
  }
  
  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _orderController.dispose();
    super.dispose();
  }
  
  void _onContentChanged() {
    _updateWordCount();
    _startAutosave();
  }
  
  void _updateWordCount() {
    final text = _contentController.text;
    setState(() {
      _wordCount = text.isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
      _readTime = _wordCount == 0 ? 0 : (_wordCount / 200).ceil();
    });
  }
  
  void _startAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(Duration(seconds: 5), _saveDraft);
  }
  
  Future<void> _saveDraft() async {
    if (_titleController.text.isEmpty && _contentController.text.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final draftData = {
      'bookId': widget.bookId,
      'title': _titleController.text,
      'content': _contentController.text,
      'order_number': _orderController.text,
      'background_image': _backgroundImageUrl,
      'saved_at': DateTime.now().toString(),
    };
    await prefs.setString('chapter_draft_${widget.bookId}', draftData.toString());
    
    if (mounted) {
      setState(() => _saving = true);
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) setState(() => _saving = false);
      });
    }
  }
  
  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftString = prefs.getString('chapter_draft_${widget.bookId}');
    
    if (draftString != null) {
      // Простое восстановление из строки
      try {
        final contentMatch = RegExp(r"'content': '([^']*)'").firstMatch(draftString);
        final titleMatch = RegExp(r"'title': '([^']*)'").firstMatch(draftString);
        final orderMatch = RegExp(r"'order_number': '([^']*)'").firstMatch(draftString);
        final bgMatch = RegExp(r"'background_image': '([^']*)'").firstMatch(draftString);
        
        if (contentMatch != null) {
          _contentController.text = contentMatch.group(1) ?? '';
        }
        if (titleMatch != null) {
          _titleController.text = titleMatch.group(1) ?? '';
        }
        if (orderMatch != null) {
          _orderController.text = orderMatch.group(1) ?? '1';
        }
        if (bgMatch != null) {
          _backgroundImageUrl = bgMatch.group(1);
        }
        _updateWordCount();
      } catch (e) {
        // Игнорируем ошибки парсинга черновика
      }
    }
  }
  
  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chapter_draft_${widget.bookId}');
    _titleController.clear();
    _contentController.clear();
    _orderController.text = '1';
    _backgroundImageUrl = null;
    _updateWordCount();
  }
  
  Future<void> _pickBackground() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        setState(() => _uploadingBackground = true);
        final file = result.files.first;
        
        if (file.bytes != null) {
          final uploadResult = await ApiService.uploadImage(
            '',
            bytes: file.bytes,
            fileName: file.name ?? 'image.png',
          );
          setState(() {
            _backgroundImageUrl = uploadResult['url'];
            _backgroundImageName = uploadResult['filename'];
            _uploadingBackground = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _uploadingBackground = false;
      });
    }
  }
  
  Future<void> _publish() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      setState(() => _error = 'Заполните название и содержание');
      return;
    }
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      await ApiService.createChapter(
        widget.bookId,
        _titleController.text,
        _contentController.text,
        orderNumber: int.tryParse(_orderController.text) ?? 1,
        backgroundImage: _backgroundImageUrl,
      );
      
      // Очищаем черновик
      await _clearDraft();
      
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
  
  void _togglePreview() {
    setState(() => _isPreview = !_isPreview);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chapterId != null ? 'Редактировать главу' : 'Новая глава'),
        actions: [
          // Кнопка предпросмотра
          IconButton(
            icon: Icon(_isPreview ? Icons.edit : Icons.visibility),
            onPressed: _togglePreview,
            tooltip: _isPreview ? 'Редактировать' : 'Предпросмотр',
          ),
          // Кнопка публикации
          IconButton(
            icon: Icon(Icons.publish),
            onPressed: _loading ? null : _publish,
            tooltip: 'Опубликовать',
          ),
        ],
      ),
      body: _isPreview
          ? _buildPreview()
          : _buildEditor(),
    );
  }
  
  Widget _buildEditor() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Загрузка обоев
          GestureDetector(
            onTap: _uploadingBackground ? null : _pickBackground,
            child: Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: _uploadingBackground
                  ? Center(child: CircularProgressIndicator())
                  : _backgroundImageUrl != null
                      ? Image.network(
                          '${ApiService.baseUrl}${_backgroundImageUrl}',
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
                            Text('Загрузить обои', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Название главы',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _startAutosave(),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _orderController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Номер главы',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _startAutosave(),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 20,
            decoration: InputDecoration(
              labelText: 'Содержание',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          SizedBox(height: 12),
          // Счётчик слов и время
          Row(
            children: [
              Icon(Icons.text_fields, size: 16, color: Colors.grey),
              SizedBox(width: 4),
              Text('$_wordCount слов', style: TextStyle(color: Colors.grey)),
              SizedBox(width: 16),
              Icon(Icons.timer, size: 16, color: Colors.grey),
              SizedBox(width: 4),
              Text('$_readTime мин', style: TextStyle(color: Colors.grey)),
              Spacer(),
              if (_saving)
                Text('Сохранено ✓', style: TextStyle(color: Colors.green)),
            ],
          ),
          if (_error != null) ...[
            SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red)),
          ],
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _publish,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: _loading
                      ? CircularProgressIndicator()
                      : Text('Опубликовать'),
                ),
              ),
              SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.delete_outline),
                onPressed: _clearDraft,
                tooltip: 'Очистить черновик',
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreview() {
    return Container(
      decoration: _backgroundImageUrl != null
          ? BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('${ApiService.baseUrl}${_backgroundImageUrl}'),
                fit: BoxFit.cover,
              ),
            )
          : null,
      child: Container(
        color: _backgroundImageUrl != null
            ? Colors.black.withOpacity(0.6)
            : Colors.white,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleController.text.isEmpty ? 'Название главы' : _titleController.text,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _backgroundImageUrl != null ? Colors.white : Colors.black,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '$_wordCount слов • $_readTime мин',
                style: TextStyle(
                  fontSize: 14,
                  color: _backgroundImageUrl != null ? Colors.white70 : Colors.grey,
                ),
              ),
              SizedBox(height: 24),
              Text(
                _contentController.text.isEmpty ? 'Содержание главы...' : _contentController.text,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.5,
                  color: _backgroundImageUrl != null ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}