// ignore_for_file: file_names, use_build_context_synchronously, sort_child_properties_last, deprecated_member_use

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selectedPageIndex = 0; // 0: Unapproved, 1: Approved, 2: Users

  Future<Uint8List?> fetchImageFromProxy(String path) async {
    final proxyUrl =
        'https://us-central1-bookmate-ec92e.cloudfunctions.net/api/image?path=$path';
    try {
      final response = await http.get(Uri.parse(proxyUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        debugPrint("🧨 Failed to fetch image: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("🧨 Proxy fetch error: $e");
    }
    return null;
  }

  Future<void> _approveBook(String bookId) async {
    await FirebaseFirestore.instance
        .collection('market_books')
        .doc(bookId)
        .update({'approved': true});
  }

  Future<void> _deleteBook(String bookId) async {
    await FirebaseFirestore.instance
        .collection('market_books')
        .doc(bookId)
        .delete();
  }

  Future<void> _deleteUser(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [_buildTopBar(), Expanded(child: _buildContentPage())],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📚 BookMate",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 40),
          _sidebarItem(Icons.pending, "Unapproved Books", 0),
          _sidebarItem(Icons.check_circle, "Approved Books", 1),
          _sidebarItem(Icons.people, "Users", 2),
          _sidebarItem(Icons.report, "Reports", 3),

          const Spacer(),
          _sidebarItem(Icons.logout, "Log out", -1),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String title, int index) {
    final bool selected = selectedPageIndex == index;
    return InkWell(
      onTap: () {
        if (index == -1) {
          Navigator.of(context).pop();
        } else {
          setState(() => selectedPageIndex = index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration:
            selected
                ? BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                )
                : null,
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? Colors.blue : Colors.grey),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.blue : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Admin Dashboard",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Row(
            children: const [
              Icon(Icons.notifications_none),
              SizedBox(width: 16),
              Icon(Icons.settings),
              SizedBox(width: 16),
              CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.person),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentPage() {
    switch (selectedPageIndex) {
      case 0:
        return _buildBookList(approved: false, showApprove: true);
      case 1:
        return _buildBookList(approved: true, showApprove: false);
      case 2:
        return _buildUserList();
      case 3:
        return _buildReportsList();

      default:
        return const Center(child: Text("Select a page"));
    }
  }

  Widget _buildReportsList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('reports')
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs;

        if (reports.isEmpty) {
          return const Center(child: Text('No reports found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index].data() as Map<String, dynamic>;
            final bookId = report['book_id'];
            final reporterId = report['reported_by'];
            final ownerId = report['book_owner'];
            final reason = report['reason'] ?? 'No reason';
            final time = (report['timestamp'] as Timestamp).toDate();

            return FutureBuilder<List<DocumentSnapshot>>(
              future: Future.wait([
                FirebaseFirestore.instance
                    .collection('market_books')
                    .doc(bookId)
                    .get(),
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(reporterId)
                    .get(),
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(ownerId)
                    .get(),
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  );
                }

                final bookDoc = snapshot.data![0];
                final reporterDoc = snapshot.data![1];
                final ownerDoc = snapshot.data![2];

                final book = bookDoc.data() as Map<String, dynamic>? ?? {};
                final reporter =
                    reporterDoc.data() as Map<String, dynamic>? ?? {};
                final owner = ownerDoc.data() as Map<String, dynamic>? ?? {};

                return Card(
                  color: Colors.red.shade50,
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kitap görseli
                        if ((book['cover_url'] ?? '').toString().isNotEmpty)
                          FutureBuilder<Uint8List?>(
                            future: fetchImageFromProxy(
                              "covers/${Uri.decodeFull(Uri.parse(book['cover_url']).path).split('/').last}",
                            ),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return Container(
                                  width: 90,
                                  height: 120,
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              } else if (snap.hasData && snap.data != null) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    snap.data!,
                                    width: 90,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              } else {
                                return Container(
                                  width: 90,
                                  height: 120,
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 40,
                                  ),
                                );
                              }
                            },
                          )
                        else
                          Container(
                            width: 90,
                            height: 120,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported),
                          ),
                        const SizedBox(width: 16),

                        // Kitap ve kullanıcı bilgileri + butonlar
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "📘 ${book['title'] ?? 'Book Title'}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text("🧾 Reason: $reason"),
                              Text(
                                "👤 Reported by: ${reporter['fullName'] ?? reporterId} (${reporter['email'] ?? ''})",
                              ),
                              Text(
                                "📚 Book Owner: ${owner['fullName'] ?? ownerId} (${owner['email'] ?? ''})",
                              ),
                              Text("💰 Price: ${book['price'] ?? 'N/A'} ₺"),
                              Text("✍️ Author: ${book['author'] ?? 'N/A'}"),
                              Text("⏰ Time: $time"),
                              const SizedBox(height: 10),

                              // Aksiyon Butonları
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await FirebaseFirestore.instance
                                          .collection('reports')
                                          .doc(reports[index].id)
                                          .delete();
                                    },
                                    icon: const Icon(
                                      Icons.delete_forever,
                                      size: 16,
                                    ),
                                    label: const Text("Raporu Sil"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _deleteBook(bookId),
                                    icon: const Icon(Icons.delete, size: 16),
                                    label: const Text("Kitabı Sil"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed:
                                        () => _editBookDialog(bookId, book),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text("Düzenle"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _buildBookList({required bool approved, required bool showApprove}) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('market_books')
              .where('approved', isEqualTo: approved)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final books = snapshot.data!.docs;
        if (books.isEmpty) {
          return const Center(child: Text('No books found.'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 3 / 4.5, // daha uzun kart görünümü
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),

          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            final data = book.data() as Map<String, dynamic>;
            final coverUrl = data['cover_url']?.toString();
            final uri = Uri.parse(coverUrl!);
            final fileName = Uri.decodeFull(uri.path).split('/').last;
            final imagePath = "covers/$fileName";

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: FutureBuilder<Uint8List?>(
                      future: fetchImageFromProxy(imagePath),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 140,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else if (snap.hasData && snap.data != null) {
                          return Image.memory(
                            snap.data!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          );
                        } else {
                          return Container(
                            height: 140,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 48),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text("Author: ${data['author'] ?? ''}"),
                        Text("Price: ${data['price']} ₺"),
                        Text("Edition: ${data['edition'] ?? ''}"),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (showApprove)
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                onPressed: () => _approveBook(book.id),
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.orange,
                              ),
                              onPressed: () => _editBookDialog(book.id, data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteBook(book.id),
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
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data!.docs;
        if (users.isEmpty) {
          return const Center(child: Text('Users not found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final data = user.data() as Map<String, dynamic>;
            final profileUrl = data['profile_image_url']?.toString();
            final imagePath =
                profileUrl != null
                    ? "profile_images/${profileUrl.split('%2F').last.split('?').first}"
                    : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  imagePath != null
                      ? FutureBuilder<Uint8List?>(
                        future: fetchImageFromProxy(imagePath),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircleAvatar(
                              child: CircularProgressIndicator(),
                            );
                          } else if (snapshot.hasData &&
                              snapshot.data != null) {
                            return CircleAvatar(
                              radius: 28,
                              backgroundImage: MemoryImage(snapshot.data!),
                            );
                          } else {
                            return const CircleAvatar(
                              radius: 28,
                              child: Icon(Icons.person),
                            );
                          }
                        },
                      )
                      : const CircleAvatar(
                        radius: 28,
                        child: Icon(Icons.person),
                      ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['fullName'] ?? 'Username',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['email'] ?? 'No Email',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteUser(user.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editBookDialog(
    String bookId,
    Map<String, dynamic> bookData,
  ) async {
    final titleController = TextEditingController(text: bookData['title']);
    final authorController = TextEditingController(text: bookData['author']);
    final priceController = TextEditingController(
      text: bookData['price']?.toString(),
    );
    final editionController = TextEditingController(text: bookData['edition']);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Book'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: authorController,
                  decoration: const InputDecoration(labelText: 'Author'),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: editionController,
                  decoration: const InputDecoration(labelText: 'Edition'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('market_books')
                    .doc(bookId)
                    .update({
                      'title': titleController.text.trim(),
                      'author': authorController.text.trim(),
                      'price':
                          double.tryParse(priceController.text.trim()) ?? 0.0,
                      'edition': editionController.text.trim(),
                      'approved': false,
                    });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
