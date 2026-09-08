import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'reviews_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Map<String, dynamic> book;
  
  BookDetailScreen({required this.book});
  
  @override
  _BookDetailScreenState createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  List<dynamic> _chapters = [];
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _rating = {'average': 0, 'count': 0};
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final chapters = await ApiService.getChapters(widget.book['id']);
      final rating = await ApiService.getAverageRating(widget.book['id']);
      setState(() {
        _chapters = chapters;
        _rating = rating;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book['title'] ?? 'Книга'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    // Информация о книге
                    Container(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.book, size: 60, color: Colors.deepPurple),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.book['title'] ?? '',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      widget.book['description'] ?? 'Нет описания',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 24),
                              SizedBox(width: 4),
                              Text(
                                '${_rating['average']} (${_rating['count']} оценок)',
                                style: TextStyle(fontSize: 16),
                              ),
                              Spacer(),
                              IconButton(
                                icon: Icon(Icons.rate_review),
                                onPressed: () {
                                  _showRatingDialog();
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.reviews),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReviewsScreen(bookId: widget.book['id']),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(),
                    // Список глав
                    Expanded(
                      child: _chapters.isEmpty
                          ? Center(child: Text('Глав пока нет'))
                          : ListView.builder(
                              padding: EdgeInsets.all(16),
                              itemCount: _chapters.length,
                              itemBuilder: (context, index) {
                                final chapter = _chapters[index];
                                return Card(
                                  margin: EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Text('${chapter['order_number']}'),
                                    ),
                                    title: Text(chapter['title']),
                                    trailing: Icon(Icons.chevron_right),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChapterReadScreen(
                                            chapter: chapter,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreateChapterDialog();
        },
        child: Icon(Icons.add),
      ),
    );
  }
  
  void _showRatingDialog() {
    showDialog(
      context: context,
      builder: (context) => RatingDialog(bookId: widget.book['id']),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }
  
  void _showCreateChapterDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateChapterDialog(bookId: widget.book['id']),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }
}

class ChapterReadScreen extends StatelessWidget {
  final Map<String, dynamic> chapter;
  
  ChapterReadScreen({required this.chapter});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(chapter['title'] ?? 'Глава'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapter['title'] ?? '',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            Text(
              chapter['content'] ?? '',
              style: TextStyle(fontSize: 18, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class RatingDialog extends StatefulWidget {
  final int bookId;
  
  RatingDialog({required this.bookId});
  
  @override
  _RatingDialogState createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _stars = 5;
  final _reviewController = TextEditingController();
  bool _isAnonymous = false;
  bool _loading = false;
  String? _error;
  
  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }
  
  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ApiService.createRating(
        widget.bookId,
        _stars,
        review: _reviewController.text.isEmpty ? null : _reviewController.text,
        isAnonymous: _isAnonymous,
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
    return AlertDialog(
      title: Text('Оценить книгу'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _stars ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: () => setState(() => _stars = index + 1),
              );
            }),
          ),
          TextField(
            controller: _reviewController,
            maxLength: 300,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Отзыв (до 300 символов)',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            title: Text('Анонимный отзыв'),
            value: _isAnonymous,
            onChanged: (value) => setState(() => _isAnonymous = value),
          ),
          if (_error != null) Text(_error!, style: TextStyle(color: Colors.red)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: Text('Отправить'),
        ),
      ],
    );
  }
}

class CreateChapterDialog extends StatefulWidget {
  final int bookId;
  
  CreateChapterDialog({required this.bookId});
  
  @override
  _CreateChapterDialogState createState() => _CreateChapterDialogState();
}

class _CreateChapterDialogState extends State<CreateChapterDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _orderController = TextEditingController(text: '1');
  bool _loading = false;
  String? _error;
  
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _orderController.dispose();
    super.dispose();
  }
  
  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      setState(() => _error = 'Заполните все поля');
      return;
    }
    
    setState(() => _loading = true);
    try {
      await ApiService.createChapter(
        widget.bookId,
        _titleController.text,
        _contentController.text,
        orderNumber: int.tryParse(_orderController.text) ?? 1,
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
    return AlertDialog(
      title: Text('Новая глава'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Название главы',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: 'Содержание',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _orderController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Номер главы',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: Text('Создать'),
        ),
      ],
    );
  }
}