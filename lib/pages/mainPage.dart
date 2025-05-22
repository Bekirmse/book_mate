// ignore_for_file: file_names, sort_child_properties_last, use_build_context_synchronously

import 'package:book_mate/pages/chatPage.dart';
import 'package:book_mate/pages/conversationsPage.dart';
import 'package:book_mate/pages/marketPage.dart';
import 'package:book_mate/pages/myBooksPage.dart';
import 'package:book_mate/pages/profilePage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool showIncoming = false;
  bool showSent = false;
  bool showSuccess = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'BookMate',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white70,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesPage()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildHeader(currentUser),
          _buildExpandableSection(
            title: "Incoming Swap Requests",
            icon: Icons.inbox,
            color: Colors.indigo,
            isExpanded: showIncoming,
            onTap: () => setState(() => showIncoming = !showIncoming),
            child: _buildExchangeList(
              query: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('book_owner', isEqualTo: currentUser?.uid)
                  .where('type', isEqualTo: 'exchange_request')
                  .orderBy('timestamp', descending: true),
              isIncoming: true,
            ),
          ),
          _buildExpandableSection(
            title: "Sent Swap Requests",
            icon: Icons.send,
            color: Colors.blue,
            isExpanded: showSent,
            onTap: () => setState(() => showSent = !showSent),
            child: _buildExchangeList(
              query: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('request_by', isEqualTo: currentUser?.uid)
                  .where('type', isEqualTo: 'exchange_request')
                  .orderBy('timestamp', descending: true),
              isIncoming: false,
            ),
          ),
          _buildExpandableSection(
            title: "Successful Transactions",
            icon: Icons.check_circle,
            color: Colors.green,
            isExpanded: showSuccess,
            onTap: () => setState(() => showSuccess = !showSuccess),
            child: _buildSuccessList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConversationsPage()),
          );
        },
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.chat),
        tooltip: 'Mesajlar',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: const Icon(Icons.home), onPressed: () {}),
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
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MarketPage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.push(
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

  Widget _buildSuccessList() {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    final swapStream =
        FirebaseFirestore.instance
            .collection('successful_swaps')
            .where('accepted_by', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots();

    final purchaseStream =
        FirebaseFirestore.instance
            .collection('successful_purchases')
            .where('buyer_id', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots();

    return FutureBuilder<List<QuerySnapshot>>(
      future: Future.wait([swapStream.first, purchaseStream.first]),
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text("Henüz başarılı işlem yok.")),
          );
        }

        final swapDocs = snapshot.data![0].docs;
        final purchaseDocs = snapshot.data![1].docs;

        final combined = [
          ...swapDocs.map((doc) => {'type': 'swap', 'doc': doc}),
          ...purchaseDocs.map((doc) => {'type': 'purchase', 'doc': doc}),
        ];

        combined.sort((a, b) {
          final aDoc = a['doc'] as QueryDocumentSnapshot?;
          final bDoc = b['doc'] as QueryDocumentSnapshot?;
          final aTime = (aDoc?.data() as Map?)?['timestamp'] as Timestamp?;
          final bTime = (bDoc?.data() as Map?)?['timestamp'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: combined.length,
          itemBuilder: (context, index) {
            final type = combined[index]['type'];
            final doc = combined[index]['doc'] as QueryDocumentSnapshot;
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp).toDate();

            return FutureBuilder<List<DocumentSnapshot>>(
              future:
                  type == 'swap'
                      ? Future.wait([
                        FirebaseFirestore.instance
                            .collection('market_books')
                            .doc(data['offered_book_id'])
                            .get(),
                        FirebaseFirestore.instance
                            .collection('market_books')
                            .doc(data['requested_book_id'])
                            .get(),
                      ])
                      : Future.wait([
                        FirebaseFirestore.instance
                            .collection('market_books')
                            .doc(data['book_id'])
                            .get(),
                      ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  );
                }

                final bookA =
                    snapshot.data![0].data() as Map<String, dynamic>? ?? {};
                final bookB =
                    type == 'swap'
                        ? snapshot.data![1].data() as Map<String, dynamic>? ??
                            {}
                        : {};

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              type == 'swap'
                                  ? Icons.swap_horiz
                                  : Icons.shopping_cart,
                              color:
                                  type == 'swap' ? Colors.orange : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              type == 'swap'
                                  ? "Swap Successful"
                                  : "Purchase Successful",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (type == 'swap')
                          Text(
                            "${bookA['title'] ?? 'Book'} ↔ ${bookB['title'] ?? 'Book'}",
                            style: const TextStyle(fontSize: 15),
                          )
                        else
                          Text(
                            "${bookA['title'] ?? 'Book'} was purchased.",
                            style: const TextStyle(fontSize: 15),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          "📅 ${timestamp.day}.${timestamp.month}.${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(User? user) {
    if (user == null) return const SizedBox();

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final fullName = data?['fullName'] ?? "kullanıcı";

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                "Hi $fullName 👋",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required Color color,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: color),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey,
            ),
            onTap: onTap,
          ),
          if (isExpanded)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
        ],
      ),
    );
  }

  Widget _buildExchangeList({required Query query, required bool isIncoming}) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Bir hata oluştu: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              isIncoming
                  ? 'You have no incoming exchange requests.'
                  : "You haven't started a trade yet.",
              style: const TextStyle(fontSize: 16),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            if (!data.containsKey('offered_book_id') ||
                !data.containsKey('book_id')) {
              return const SizedBox.shrink();
            }

            final requesterId = data['request_by'];
            final bookOwnerId = data['book_owner'];
            final requestedBookId = data['book_id'];
            final offeredBookId = data['offered_book_id'];
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            final otherUserId = isIncoming ? requesterId : bookOwnerId;

            return FutureBuilder<List<DocumentSnapshot>>(
              future: Future.wait([
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                FirebaseFirestore.instance
                    .collection('market_books')
                    .doc(requestedBookId)
                    .get(),
                FirebaseFirestore.instance
                    .collection('market_books')
                    .doc(offeredBookId)
                    .get(),
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  );
                }

                final otherUserDoc = snapshot.data![0];
                final requestedBookDoc = snapshot.data![1];
                final offeredBookDoc = snapshot.data![2];

                if (!otherUserDoc.exists ||
                    !requestedBookDoc.exists ||
                    !offeredBookDoc.exists) {
                  return const Center(
                    child: Text(
                      "Data is missing or deleted.",
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                final otherUserName = otherUserDoc['fullName'] ?? 'Bilinmeyen';
                final requestedBook =
                    requestedBookDoc.data() as Map<String, dynamic>;
                final offeredBook =
                    offeredBookDoc.data() as Map<String, dynamic>;

                final yourBook = isIncoming ? requestedBook : offeredBook;
                final theirBook = isIncoming ? offeredBook : requestedBook;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIncoming
                              ? "$otherUserName size takas teklifi gönderdi:"
                              : "$otherUserName adlı kullanıcıya takas teklifi gönderdiniz:",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildBookCard(
                              theirBook['cover_url'],
                              theirBook['title'],
                              'Onun Kitabı',
                            ),
                            const Icon(
                              Icons.compare_arrows,
                              size: 32,
                              color: Colors.grey,
                            ),
                            _buildBookCard(
                              yourBook['cover_url'],
                              yourBook['title'],
                              'Senin Kitabın',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (timestamp != null)
                          Text(
                            "📅 ${timestamp.toLocal()}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.chat,
                                color: Colors.indigo,
                              ),
                              tooltip: 'Mesaj Gönder',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => ChatPage(
                                          receiverId: otherUserId,
                                          bookTitle: yourBook['title'],
                                        ),
                                  ),
                                );
                              },
                            ),
                            if (!isIncoming)
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                tooltip: 'Takas isteğini iptal et',
                                onPressed: () async {
                                  await docs[index].reference.delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Takas isteği iptal edildi.",
                                      ),
                                    ),
                                  );
                                },
                              ),
                            if (isIncoming) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                tooltip: 'Kabul Et',
                                onPressed: () async {
                                  try {
                                    // 1. Kitapları al
                                    final requestedBookRef = FirebaseFirestore
                                        .instance
                                        .collection('market_books')
                                        .doc(requestedBookId);
                                    final offeredBookRef = FirebaseFirestore
                                        .instance
                                        .collection('market_books')
                                        .doc(offeredBookId);

                                    // 2. Kitapların sahipliğini değiştir
                                    await requestedBookRef.update({
                                      'owner_id': requesterId,
                                    });
                                    await offeredBookRef.update({
                                      'owner_id': bookOwnerId,
                                    });

                                    // 3. Başarılı takas koleksiyonuna ekle
                                    await FirebaseFirestore.instance
                                        .collection('successful_swaps')
                                        .add({
                                          'requested_book_id': requestedBookId,
                                          'offered_book_id': offeredBookId,
                                          'accepted_by': bookOwnerId,
                                          'timestamp':
                                              FieldValue.serverTimestamp(),
                                        });

                                    // 4. Bildirimi (notification) sil
                                    await docs[index].reference.delete();

                                    // 5. Geri bildirim ver
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Takas başarıyla tamamlandı.",
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Hata: ${e.toString()}"),
                                      ),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                tooltip: 'Reddet',
                                onPressed: () async {
                                  await docs[index].reference.delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Takas reddedildi."),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Kitap kutucuğu (kapak + başlık + etiket)
  Widget _buildBookCard(String? imageUrl, String? title, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl ?? 'https://via.placeholder.com/80x120.png?text=Kitap',
              width: 80,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title ?? 'Kitap',
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Chip(
            label: Text(label, style: const TextStyle(fontSize: 11)),
            backgroundColor:
                label == 'Senin Kitabın'
                    ? Colors.blue[100]
                    : Colors.orange[100],
          ),
        ],
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Favorite Books',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future:
            FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('favorites')
                .get(),
        builder: (context, favSnapshot) {
          if (!favSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final favoriteDocs = favSnapshot.data!.docs;

          if (favoriteDocs.isEmpty) {
            return const Center(child: Text('No favorite book found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favoriteDocs.length,
            itemBuilder: (context, index) {
              final bookRef =
                  favoriteDocs[index]['bookRef'] as DocumentReference;

              return FutureBuilder<DocumentSnapshot>(
                future: bookRef.get(),
                builder: (context, bookSnap) {
                  if (!bookSnap.hasData) {
                    return const SizedBox();
                  }

                  final book = bookSnap.data!;
                  final data = book.data() as Map<String, dynamic>?;

                  if (data == null) {
                    return const ListTile(
                      title: Text(
                        'The book has been deleted or is inaccessible.',
                      ),
                    );
                  }

                  final title = data['title'] ?? '';
                  final author = data['author'] ?? '';
                  final price = data['price']?.toDouble() ?? 0.0;
                  final coverUrl = data['cover_url'] ?? '';
                  final category = data['category'] ?? '';
                  final location = data['location'] ?? '';
                  final ownerName = data['owner_name'] ?? '';
                  final rating = data['rating']?.toDouble() ?? 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            coverUrl,
                            width: 90,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Author: $author',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Category: $category',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                'Location: $location',
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                'Owner: $ownerName',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.orange,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${price.toStringAsFixed(2)} ₺',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.open_in_new,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    "Go to Details",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => MarketPage(
                                              scrollToBookId: book.id,
                                            ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    backgroundColor: Colors.indigo,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
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
          );
        },
      ),
    );
  }
}
