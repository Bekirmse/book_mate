// ignore_for_file: file_names, use_build_context_synchronously, sort_child_properties_last

import 'package:book_mate/pages/ConversationsPage.dart';
import 'package:book_mate/pages/marketPage.dart';
import 'package:book_mate/pages/myBooksPage.dart';
import 'package:book_mate/pages/profilePage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  Future<String?> getFullName(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data()?['fullName'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text(
          'Home',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Favorilerim',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConversationsPage()),
              );
            },
          ),
        ],
      ),

      body: const Center(child: Text('Home page content will come here.')),

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                // Ana sayfaya yönlendirme gerekmez
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
            const SizedBox(width: 48), // FAB boşluğu
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

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
          'My Favorites',
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
            return const Center(child: Text('No favorite books.'));
          }

          return ListView.builder(
            itemCount: favoriteDocs.length,
            itemBuilder: (context, index) {
              final bookRef =
                  favoriteDocs[index]['bookRef'] as DocumentReference;

              return FutureBuilder<DocumentSnapshot>(
                future: bookRef.get(),
                builder: (context, bookSnap) {
                  if (!bookSnap.hasData) {
                    return const ListTile(title: Text('Loading...'));
                  }

                  final book = bookSnap.data!;
                  final bookData = book.data();

                  // 🔒 Null kontrolü
                  if (bookData == null) {
                    return const ListTile(
                      title: Text('Book not found or deleted.'),
                    );
                  }

                  final data = bookData as Map<String, dynamic>;

                  return ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MarketPage(scrollToBookId: book.id),
                        ),
                      );
                    },
                    leading: Image.network(
                      data['cover_url'],
                      width: 50,
                      fit: BoxFit.cover,
                    ),
                    title: Text(data['title']),
                    subtitle: Text(data['author']),
                    trailing: Text('${data['price']} ₺'),
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
