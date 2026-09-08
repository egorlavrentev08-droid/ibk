import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReviewsScreen extends StatefulWidget {
  final int bookId;
  
  ReviewsScreen({required this.bookId});
  
  @override
  _ReviewsScreenState createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<dynamic> _reviews = [];
  bool _loading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadReviews();
  }
  
  Future<void> _loadReviews() async {
    setState(() => _loading = true);
    try {
      final reviews = await ApiService.getBookReviews(widget.bookId);
      setState(() {
        _reviews = reviews;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }
  
  Future<void> _vote(int ratingId, String voteType) async {
    try {
      await ApiService.voteReview(ratingId, voteType);
      await _loadReviews();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Отзывы'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _reviews.isEmpty
                  ? Center(child: Text('Отзывов пока нет'))
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _reviews.length,
                      itemBuilder: (context, index) {
                        final review = _reviews[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      child: Text(
                                        review['username'][0]?.toUpperCase() ?? '?',
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            review['username'] ?? 'Аноним',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Row(
                                            children: List.generate(5, (i) {
                                              return Icon(
                                                i < review['stars'] ? Icons.star : Icons.star_border,
                                                size: 16,
                                                color: Colors.amber,
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Text(
                                  review['review'] ?? '',
                                  style: TextStyle(fontSize: 16),
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      icon: Icon(Icons.thumb_up, size: 20),
                                      label: Text('${review['likes']}'),
                                      onPressed: () => _vote(review['id'], 'like'),
                                    ),
                                    SizedBox(width: 16),
                                    TextButton.icon(
                                      icon: Icon(Icons.thumb_down, size: 20),
                                      label: Text('${review['dislikes']}'),
                                      onPressed: () => _vote(review['id'], 'dislike'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}