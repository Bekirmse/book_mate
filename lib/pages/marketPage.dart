// ignore_for_file: file_names, use_build_context_synchronously

import 'package:book_mate/pages/chatPage.dart';
import 'package:book_mate/pages/mainPage.dart';
import 'package:book_mate/pages/myBooksPage.dart';
import 'package:book_mate/pages/profilePage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MarketPage extends StatefulWidget {
  final String? scrollToBookId;

  const MarketPage({super.key, this.scrollToBookId});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  Set<String> favoriteBookIds = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchFavoriteIds().then((ids) {
      setState(() {
        favoriteBookIds = ids;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scrollToBookId != null) {
        _scrollToBook(widget.scrollToBookId!);
      }
    });
  }

  String? selectedCategory;
  String? selectedLocation;
  RangeValues selectedPriceRange = const RangeValues(0, 500);

  final List<String> categories = [
    'None',
    'Fiction',
    'Non-fiction',
    'Science Fiction',
    'Fantasy',
    'Romance',
    'Mystery',
    'Thriller',
    'Biography',
    'History',
    'Children',
    'Self-help',
    'Education',
  ];

  final List<String> locations = [
    'None',
    'Lefkoşa',
    'Gazimağusa',
    'Girne',
    'Güzelyurt',
    'İskele',
    'Lefke',
  ];

  Future<void> _scrollToBook(String bookId) async {
    final books = await fetchBooks();
    final index = books.indexWhere((book) => book.id == bookId);

    // ScrollView hazır değilse bekle
    await Future.delayed(const Duration(milliseconds: 300));

    if (index != -1 && _scrollController.hasClients) {
      _scrollController.animateTo(
        index * 72.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<List<DocumentSnapshot>> fetchBooks() async {
    Query query = FirebaseFirestore.instance
        .collection('market_books')
        .where('approved', isEqualTo: true);

    if (selectedCategory != null && selectedCategory!.isNotEmpty) {
      query = query.where('category', isEqualTo: selectedCategory);
    }

    if (selectedLocation != null && selectedLocation!.isNotEmpty) {
      query = query.where('location', isEqualTo: selectedLocation);
    }

    // Firestore fiyat aralığı sorgusu yoksa client-side filtre uygula
    final snapshot = await query.get();

    return snapshot.docs.where((doc) {
      final price = (doc['price'] ?? 0).toDouble();
      return price >= selectedPriceRange.start &&
          price <= selectedPriceRange.end;
    }).toList();
  }

  Future<Set<String>> fetchFavoriteIds() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return {};

    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .get();

    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  void _showReportDialog(String bookId, String bookOwnerId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Report Book"),
            content: TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Please specify the reason...",
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  await FirebaseFirestore.instance.collection("reports").add({
                    'book_id': bookId,
                    'reported_by': user.uid,
                    'reason': reasonController.text.trim(),
                    'timestamp': Timestamp.now(),
                    'book_owner': bookOwnerId,
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Notification sent.")),
                  );
                },
                child: const Text("Send"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Market',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        foregroundColor: Colors.black,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: fetchBooks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final books = snapshot.data!;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search book..',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items:
                              categories.map((category) {
                                return DropdownMenuItem(
                                  value: category == 'None' ? null : category,
                                  child: Text(category),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() => selectedCategory = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedLocation,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                          ),
                          items:
                              locations.map((location) {
                                return DropdownMenuItem(
                                  value: location == 'None' ? null : location,
                                  child: Text(location),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() => selectedLocation = value);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(
                    "Max Price: ${selectedPriceRange.end.toStringAsFixed(0)} ₺",
                  ),
                  RangeSlider(
                    values: selectedPriceRange,
                    min: 0,
                    max: 500,
                    divisions: 50,
                    labels: RangeLabels(
                      selectedPriceRange.start.round().toString(),
                      selectedPriceRange.end.round().toString(),
                    ),
                    onChanged: (values) {
                      setState(() {
                        selectedPriceRange = values;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        selectedCategory = null;
                        selectedLocation = null;
                        selectedPriceRange = const RangeValues(0, 500);
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Filters'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),

                  const SizedBox(height: 16),
                  const Center(child: Chip(label: Text('Featured Books'))),

                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  book['cover_url'],
                                  width: 120,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                book['title'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'New Books',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 1,
                          childAspectRatio: 2.4,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      final bookId = book.id;
                      final bookOwnerId = book['owner_id'];
                      if (bookOwnerId == null) {
                        return const SizedBox(); // ya da skip
                      }

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              // ignore: deprecated_member_use
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),

                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                book['cover_url'],
                                width: 70,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book['title'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    book['author'] ?? '',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${book['price']} ₺',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (FirebaseAuth.instance.currentUser?.uid !=
                                bookOwnerId)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .collection('market_books')
                                              .doc(bookId)
                                              .update({'sold': true});

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Kitap başarıyla satın alındı!',
                                              ),
                                            ),
                                          );
                                          setState(() {});
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          minimumSize: const Size(80, 36),
                                          textStyle: const TextStyle(
                                            fontSize: 14,
                                          ),
                                        ),
                                        child: const Text("Buy"),
                                      ),

                                      const SizedBox(height: 0),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final currentUser =
                                              FirebaseAuth.instance.currentUser;
                                          if (currentUser == null) return;

                                          final existing =
                                              await FirebaseFirestore.instance
                                                  .collection('notifications')
                                                  .where(
                                                    'book_id',
                                                    isEqualTo: bookId,
                                                  )
                                                  .where(
                                                    'request_by',
                                                    isEqualTo: currentUser.uid,
                                                  )
                                                  .get();

                                          if (existing.docs.isEmpty) {
                                            await FirebaseFirestore.instance
                                                .collection('notifications')
                                                .add({
                                                  'type': 'exchange_request',
                                                  'book_id': bookId,
                                                  'book_owner': bookOwnerId,
                                                  'request_by': currentUser.uid,
                                                  'timestamp': Timestamp.now(),
                                                });

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Takas isteği gönderildi!',
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Zaten takas isteği göndermişsiniz!',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          minimumSize: const Size(80, 36),
                                          textStyle: const TextStyle(
                                            fontSize: 14,
                                          ),
                                        ),
                                        child: const Text("Swap"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => ChatPage(
                                                    receiverId: bookOwnerId,
                                                    bookTitle:
                                                        book['title'] ?? '',
                                                  ),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blueAccent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          minimumSize: const Size(80, 36),
                                          textStyle: const TextStyle(
                                            fontSize: 14,
                                          ),
                                        ),
                                        child: const Text("Send Message"),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) {
                                      if (value == 'report') {
                                        _showReportDialog(bookId, bookOwnerId);
                                      }
                                    },
                                    itemBuilder:
                                        (context) => [
                                          const PopupMenuItem(
                                            value: 'report',
                                            child: Text('Report this book'),
                                          ),
                                        ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MainPage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.menu_book),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyBooksPage()),
                );
              },
            ),
            const SizedBox(width: 48),
            IconButton(icon: const Icon(Icons.shopping_cart), onPressed: () {}),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
