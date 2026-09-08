import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import 'reviews_screen.dart';
import 'chapter_editor_screen.dart';

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
                              widget.book['cover_image'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        '${ApiService.baseUrl}${widget.book['cover_image']}',
                                        width: 80,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(Icons.book, size: 60, color: Colors.deepPurple);
                                        },
                                      ),
                                    )
                                  : Icon(Icons.book, size: 60, color: Colors.deepPurple),
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
                                    subtitle: Text(
                                      '${chapter['word_count']} слов • ${chapter['read_time']} мин • ${chapter['published_at'] != null ? chapter['published_at'].toString().substring(0, 10) : ''}',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    trailing: Icon(Icons.chevron_right),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChapterReadScreen(
                                            chapters: _chapters,
                                            currentIndex: index,
                                            bookId: widget.book['id'],
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterEditorScreen(bookId: widget.book['id']),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }
}

class ChapterReadScreen extends StatefulWidget {
  final List<dynamic> chapters;
  final int currentIndex;
  final int bookId;
  
  ChapterReadScreen({
    required this.chapters,
    required this.currentIndex,
    required this.bookId,
  });
  
  @override
  _ChapterReadScreenState createState() => _ChapterReadScreenState();
}

class _ChapterReadScreenState extends State<ChapterReadScreen> {
  late int _currentIndex;
  late ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _scrollController = ScrollController();
    _loadReadingPosition();
  }
  
  @override
  void dispose() {
    _saveReadingPosition();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _saveReadingPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reading_position_${widget.bookId}', _currentIndex.toString());
    await prefs.setDouble('scroll_position_${widget.bookId}', _scrollController.offset);
  }
  
  Future<void> _loadReadingPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getString('reading_position_${widget.bookId}');
    final savedScroll = prefs.getDouble('scroll_position_${widget.bookId}');
    
    if (savedIndex != null && savedScroll != null) {
      final index = int.tryParse(savedIndex);
      if (index != null && index >= 0 && index < widget.chapters.length) {
        _currentIndex = index;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(savedScroll);
        }
      });
    }
  }
  
  void _goToChapter(int index) {
    if (index < 0 || index >= widget.chapters.length) return;
    setState(() {
      _currentIndex = index;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _saveReadingPosition();
  }
  
  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapters[_currentIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(chapter['title'] ?? 'Глава'),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! > 0) {
              // Свайп вправо — предыдущая глава
              _goToChapter(_currentIndex - 1);
            } else if (details.primaryVelocity! < 0) {
              // Свайп влево — следующая глава
              _goToChapter(_currentIndex + 1);
            }
          }
        },
        child: Container(
          decoration: chapter['background_image'] != null
              ? BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage('${ApiService.baseUrl}${chapter['background_image']}'),
                    fit: BoxFit.cover,
                  ),
                )
              : null,
          child: Container(
            color: chapter['background_image'] != null
                ? Colors.black.withOpacity(0.6)
                : Colors.transparent,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter['title'] ?? '',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: chapter['background_image'] != null ? Colors.white : null,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Глава ${chapter['order_number']} • ${chapter['word_count']} слов • ${chapter['read_time']} мин',
                    style: TextStyle(
                      fontSize: 14,
                      color: chapter['background_image'] != null ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    chapter['content'] ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.5,
                      color: chapter['background_image'] != null ? Colors.white : null,
                    ),
                  ),
                  SizedBox(height: 24),
                  // Навигация по главам
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentIndex > 0)
                        TextButton.icon(
                          icon: Icon(Icons.arrow_back),
                          label: Text('Назад'),
                          onPressed: () => _goToChapter(_currentIndex - 1),
                        )
                      else
                        SizedBox(width: 100),
                      Text(
                        '${_currentIndex + 1} / ${widget.chapters.length}',
                        style: TextStyle(color: Colors.grey),
                      ),
                      if (_currentIndex < widget.chapters.length - 1)
                        TextButton.icon(
                          icon: Icon(Icons.arrow_forward),
                          label: Text('Вперёд'),
                          onPressed: () => _goToChapter(_currentIndex + 1),
                        )
                      else
                        SizedBox(width: 100),
                    ],
                  ),
                ],
              ),
            ),
          ),
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