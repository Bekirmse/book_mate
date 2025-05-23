// ignore_for_file: file_names, use_build_context_synchronously, deprecated_member_use, duplicate_ignore, unnecessary_string_escapes, avoid_types_as_parameter_names

import 'package:book_mate/pages/chatPage.dart';
import 'package:book_mate/pages/fake_payment_page.dart';
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
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final userEmail =
      FirebaseAuth.instance.currentUser!.email; // veya displayName

  String searchKeyword = '';

  @override
  void initState() {
    super.initState();

    initializeMissingFields();

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

    final snapshot = await query.get();

    return snapshot.docs.where((doc) {
      final price = (doc['price'] ?? 0).toDouble();
      final title = (doc['title'] ?? '').toString().toLowerCase();

      return price >= selectedPriceRange.start &&
          price <= selectedPriceRange.end &&
          (searchKeyword.isEmpty ||
              title.contains(searchKeyword.toLowerCase()));
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            title: Row(
              children: const [
                Icon(Icons.report_problem, color: Colors.redAccent),
                SizedBox(width: 8),
                Text(
                  "Report Book",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Briefly explain the situation that led to the notification:",
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Example: Fake listing, incorrect information.",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton.icon(
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
                    const SnackBar(
                      content: Text(
                        "Your report has been successfully submitted.",
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.send, size: 18, color: Colors.white),
                label: const Text(
                  "Send",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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
          if (books.isEmpty) {
            return const SizedBox(
              height: 1000,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "No books found matching the filters.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              final bookId = book.id;
              final bookOwnerId = book['owner_id'];
              final isCurrentUserOwner =
                  FirebaseAuth.instance.currentUser?.uid == bookOwnerId;

              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          Image.network(
                            book['cover_url'],
                            height: 600,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () async {
                                final userId =
                                    FirebaseAuth.instance.currentUser?.uid;
                                if (userId == null) return;

                                final favoritesRef = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .collection('favorites')
                                    .doc(bookId);

                                if (favoriteBookIds.contains(bookId)) {
                                  await favoritesRef.delete();
                                  setState(
                                    () => favoriteBookIds.remove(bookId),
                                  );
                                } else {
                                  await favoritesRef.set({
                                    'title': book['title'],
                                    'bookRef': FirebaseFirestore.instance
                                        .collection('market_books')
                                        .doc(bookId),
                                  });
                                  setState(() => favoriteBookIds.add(bookId));
                                }
                              },
                              child: Icon(
                                favoriteBookIds.contains(bookId)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: Colors.redAccent,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book['title'] ?? '',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'by ${book['author'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.black87,
                            ),
                          ),
                          const Divider(height: 20),
                          Wrap(
                            runSpacing: 8,
                            children: [
                              _buildDetailRow(
                                Icons.bookmark_outline,
                                'Edition',
                                book['edition'],
                              ),
                              _buildDetailRow(
                                Icons.sell_outlined,
                                'Price',
                                '${book['price']} ₺',
                              ),
                              _buildDetailRow(
                                Icons.category,
                                'Category',
                                book['category'],
                              ),
                              _buildDetailRow(
                                Icons.location_on_outlined,
                                'Location',
                                book['location'],
                              ),
                              _buildDetailRow(
                                Icons.person_outline,
                                'Seller',
                                book['owner_name'],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Text(
                                "Average Score: ",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const Icon(
                                Icons.star,
                                color: Colors.orange,
                                size: 18,
                              ),
                              Text(
                                ((book.data() as Map<String, dynamic>)
                                            .containsKey('average_rating')
                                        ? book['average_rating']
                                        : 0.0)
                                    .toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Bu kısım artık HERKES için geçerli
                          const SizedBox(height: 12),
                          const Text(
                            "Comments & Ratings",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<QuerySnapshot>(
                            future:
                                FirebaseFirestore.instance
                                    .collection('market_books')
                                    .doc(bookId)
                                    .collection('ratings')
                                    .orderBy('timestamp', descending: true)
                                    .limit(3)
                                    .get(),
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final docs = snap.data!.docs;
                              if (docs.isEmpty) {
                                return const Text(
                                  "No comments have been made yet.",
                                );
                              }

                              return Column(
                                children:
                                    docs.map((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final stars = data['stars'] ?? 0;
                                      final comment = data['comment'] ?? '';
                                      final timestamp =
                                          (data['timestamp'] as Timestamp?)
                                              ?.toDate();
                                      final userId = data['user_id'];

                                      return FutureBuilder<DocumentSnapshot>(
                                        future:
                                            FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(userId)
                                                .get(),
                                        builder: (context, userSnap) {
                                          String username = "Kullanıcı";
                                          if (userSnap.hasData &&
                                              userSnap.data!.exists &&
                                              userSnap.data!.data() != null) {
                                            username =
                                                userSnap.data!.get(
                                                  'fullName',
                                                ) ??
                                                "User";
                                          }

                                          return Card(
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.person,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        username,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const Spacer(),
                                                      Row(
                                                        children: List.generate(
                                                          5,
                                                          (index) {
                                                            return Icon(
                                                              index < stars
                                                                  ? Icons.star
                                                                  : Icons
                                                                      .star_border,
                                                              color:
                                                                  Colors.amber,
                                                              size: 16,
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (timestamp != null) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      "${timestamp.day}.${timestamp.month}.${timestamp.year}",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    comment,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Yorum yapma butonu SADECE kitap sahibi DEĞİLSE gösterilsin
                          if (!isCurrentUserOwner)
                            Column(
                              children: [
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildActionButton(
                                      Icons.swap_horiz,
                                      'Swap',
                                      Colors.orange,
                                      () => _openSwapDialog(
                                        context,
                                        book,
                                        bookId,
                                        bookOwnerId,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildActionButton(
                                      Icons.shopping_cart,
                                      'Buy',
                                      Colors.green,
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => FakePaymentPage(
                                                  bookId: bookId,
                                                  bookTitle: book['title'],
                                                  bookPrice:
                                                      (book['price'] ?? 0)
                                                          .toDouble(),
                                                  currentOwnerId: bookOwnerId,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _buildActionButton(
                                      Icons.message,
                                      'Send Message',
                                      Colors.blue,
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => ChatPage(
                                                  receiverId: bookOwnerId,
                                                  bookTitle: book['title'],
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    _buildActionButton(
                                      Icons.report,
                                      'Report',
                                      Colors.red,
                                      () => _showReportDialog(
                                        bookId,
                                        bookOwnerId,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.rate_review,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    "Rate / Comment",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed:
                                      () => _showRatingDialog(context, bookId),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFilterBottomSheet(context),
        backgroundColor: Colors.indigo,
        tooltip: 'Filter Books',
        child: const Icon(Icons.filter_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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

  void initializeMissingFields() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('market_books').get();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final updates = <String, dynamic>{};

      if (!data.containsKey('average_rating')) {
        updates['average_rating'] = 0.0;
      }
      if (!data.containsKey('user_ratings')) {
        updates['user_ratings'] = {};
      }

      if (updates.isNotEmpty) {
        await doc.reference.update(updates);
      }
    }
  }

  void _showRatingDialog(BuildContext context, String bookId) async {
    int selectedStars = 0;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Rate This Book",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedStars
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 30,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedStars = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Write a comment (optional)",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (selectedStars == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please select a star rating."),
                        ),
                      );
                      return;
                    }

                    final uid = FirebaseAuth.instance.currentUser!.uid;
                    final userEmail = FirebaseAuth.instance.currentUser!.email;

                    // Yorum gönder
                    await FirebaseFirestore.instance
                        .collection('market_books')
                        .doc(bookId)
                        .collection('ratings')
                        .add({
                          'user_id': uid,
                          'stars': selectedStars,
                          'comment': commentCtrl.text.trim(),
                          'timestamp': Timestamp.now(),
                          'user': userEmail,
                        });

                    // Ortalama güncelle
                    final ratingsSnap =
                        await FirebaseFirestore.instance
                            .collection('market_books')
                            .doc(bookId)
                            .collection('ratings')
                            .get();

                    final totalStars = ratingsSnap.docs.fold<int>(
                      0,
                      (sum, doc) => sum + ((doc['stars'] ?? 0) as int),
                    );
                    final average = totalStars / ratingsSnap.docs.length;

                    await FirebaseFirestore.instance
                        .collection('market_books')
                        .doc(bookId)
                        .update({'average_rating': average});

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Your rating has been submitted."),
                      ),
                    );
                  },
                  icon: const Icon(Icons.send, size: 18, color: Colors.white),
                  label: const Text(
                    "Send",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox();
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.indigo),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(value.toString(), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  void _openSwapDialog(
    BuildContext context,
    DocumentSnapshot book,
    String bookId,
    String bookOwnerId,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final myBooksSnapshot =
        await FirebaseFirestore.instance
            .collection('market_books')
            .where('owner_id', isEqualTo: currentUser.uid)
            .where('approved', isEqualTo: true)
            .get();

    if (myBooksSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You must have an approved book to trade."),
        ),
      );
      return;
    }

    String? selectedBookId;
    String? selectedBookTitle;
    double? selectedBookPrice;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Select your book for swap",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children:
                      myBooksSnapshot.docs.map((doc) {
                        final title = doc['title'] ?? '';
                        final price = doc['price']?.toDouble() ?? 0.0;
                        final docId = doc.id;
                        final isSelected = selectedBookId == docId;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedBookId = docId;
                              selectedBookTitle = title;
                              selectedBookPrice = price;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? Colors.indigo[50]
                                      : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Colors.indigo
                                        : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.book, color: Colors.indigo),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "$price ₺",
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.indigo,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send, size: 18, color: Colors.white),
                  label: const Text(
                    "Send",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (selectedBookId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please choose a book.")),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .add({
                          'type': 'exchange_request',
                          'book_id': bookId,
                          'book_title': book['title'] ?? '',
                          'book_owner': bookOwnerId,
                          'request_by': currentUser.uid,
                          'offered_book_id': selectedBookId,
                          'offered_book_title': selectedBookTitle ?? '',
                          'offered_book_price': selectedBookPrice ?? 0,
                          'timestamp': Timestamp.now(),
                        });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Trade request sent.")),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    TextEditingController searchController = TextEditingController(
      text: searchKeyword,
    ); // mevcut arama kelimesi

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Wrap(
            runSpacing: 16,
            children: [
              const Center(
                child: Text(
                  'Filter Books',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),

              // 🔍 Arama Kutusu
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Book Name',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              // 📚 Kategori Seçimi
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
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

              // 📍 Lokasyon Seçimi
              DropdownButtonFormField<String>(
                value: selectedLocation,
                decoration: InputDecoration(
                  labelText: 'Location',
                  prefixIcon: const Icon(Icons.location_on),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
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

              // 💰 Fiyat Aralığı Seçimi
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Price Range",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${selectedPriceRange.start.toInt()} ₺ - ${selectedPriceRange.end.toInt()} ₺",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      RangeSlider(
                        values: selectedPriceRange,
                        min: 0,
                        max: 1000,
                        divisions: 100,
                        labels: RangeLabels(
                          selectedPriceRange.start.round().toString(),
                          selectedPriceRange.end.round().toString(),
                        ),
                        onChanged: (values) {
                          setModalState(() {
                            selectedPriceRange = values;
                          });
                          setState(() {});
                        },
                      ),
                    ],
                  );
                },
              ),

              // 🔘 Butonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        selectedCategory = null;
                        selectedLocation = null;
                        selectedPriceRange = const RangeValues(0, 500);
                        searchKeyword = '';
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        searchKeyword = searchController.text.trim();
                      });
                    },
                    icon: const Icon(Icons.check, color: Colors.white),

                    label: const Text(
                      'Apply',
                      style: TextStyle(color: Colors.white),
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildBookCard(DocumentSnapshot book) {
    final bookId = book.id;
    final title = book['title'] ?? '';
    final author = book['author'] ?? '';
    final price = book['price']?.toDouble() ?? 0.0;
    final originalPrice = book['original_price']?.toDouble();
    final rating = book['rating']?.toDouble() ?? 4.3;
    final isOnSale = book['isOnSale'] ?? false;
    final coverUrl = book['cover_url'] ?? '';

    final isFavorited = favoriteBookIds.contains(bookId);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  coverUrl,
                  width: 70,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              if (isOnSale)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Sale',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final userId = FirebaseAuth.instance.currentUser?.uid;
                        if (userId == null) return;

                        final favoritesRef = FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .collection('favorites')
                            .doc(bookId);

                        if (isFavorited) {
                          await favoritesRef.delete();
                        } else {
                          await favoritesRef.set({'title': title});
                        }

                        setState(() {
                          if (isFavorited) {
                            favoriteBookIds.remove(bookId);
                          } else {
                            favoriteBookIds.add(bookId);
                          }
                        });
                      },
                      child: Icon(
                        isFavorited ? Icons.favorite : Icons.favorite_border,
                        color: isFavorited ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  author,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '\₺${price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.indigo,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (originalPrice != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          '\₺${originalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 16),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
