// ignore_for_file: file_names, use_build_context_synchronously, sort_child_properties_last, deprecated_member_use

import 'dart:io';
import 'package:book_mate/pages/mainPage.dart';
import 'package:book_mate/pages/marketPage.dart';
import 'package:book_mate/pages/profilePage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MyBooksPage extends StatefulWidget {
  const MyBooksPage({super.key});

  @override
  State<MyBooksPage> createState() => _MyBooksPageState();
}

class _MyBooksPageState extends State<MyBooksPage> {
  final user = FirebaseAuth.instance.currentUser!;
  List<DocumentSnapshot> myBooks = [];
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    fetchMyBooks();
  }

  Future<void> fetchMyBooks() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('market_books')
            .where('owner_id', isEqualTo: user.uid)
            .get();

    setState(() {
      myBooks = snapshot.docs;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<Map<String, String>> _uploadImage(File imageFile) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'covers/$fileName';
    final ref = FirebaseStorage.instance.ref().child(path);

    await ref.putFile(imageFile);
    final downloadUrl = await ref.getDownloadURL();

    return {'cover_url': downloadUrl, 'cover_path': path};
  }

  Future<void> _addBookDialog() async {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final priceController = TextEditingController();
    final editionController = TextEditingController();

    bool isSold = false;
    bool isSaving = false;
    _selectedImage = null;
    String? selectedCategory;
    String? selectedLocation;

    final List<String> locations = [
      'Lefkoşa',
      'Gazimağusa',
      'Girne',
      'Güzelyurt',
      'İskele',
      'Lefke',
    ];

    final List<String> categories = [
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

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Add New Book'),
                  content: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Book Name',
                          ),
                        ),
                        TextField(
                          controller: authorController,
                          decoration: const InputDecoration(
                            labelText: 'Author',
                          ),
                        ),
                        TextField(
                          controller: editionController,
                          decoration: const InputDecoration(
                            labelText: 'Edition',
                          ),
                        ),
                        TextField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price (₺)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Sold:'),
                            Checkbox(
                              value: isSold,
                              onChanged: (value) {
                                setState(() {
                                  isSold = value ?? false;
                                });
                              },
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await _pickImage();
                            setState(() {});
                          },
                          child: const Text('Select Cover Image'),
                        ),
                        if (_selectedImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_selectedImage!, height: 100),
                          ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedCategory,
                          items:
                              categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedLocation,
                          items:
                              locations.map((location) {
                                return DropdownMenuItem(
                                  value: location,
                                  child: Text(location),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedLocation = value;
                            });
                          },
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
                      onPressed:
                          isSaving
                              ? null
                              : () async {
                                if (_selectedImage == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please select an image'),
                                    ),
                                  );
                                  return;
                                }

                                setState(() => isSaving = true);

                                final userDoc =
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .get();
                                final fullName =
                                    userDoc.data()?['fullName'] ??
                                    'Unknown User';

                                final newDoc =
                                    FirebaseFirestore.instance
                                        .collection('market_books')
                                        .doc();
                                final uploadResult = await _uploadImage(
                                  _selectedImage!,
                                );

                                await newDoc.set({
                                  'book_id': newDoc.id,
                                  'title': titleController.text.trim(),
                                  'author': authorController.text.trim(),
                                  'edition': editionController.text.trim(),
                                  'is_sold': isSold,
                                  'price': double.tryParse(
                                    priceController.text,
                                  ),
                                  'owner_id': user.uid,
                                  'owner_name': fullName,
                                  'rating': 0.0,
                                  'cover_url': uploadResult['cover_url'],
                                  'cover_path': uploadResult['cover_path'],
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'approved': false,
                                  'category': selectedCategory ?? '',
                                  'location': selectedLocation ?? '',
                                });

                                Navigator.pop(context);
                                fetchMyBooks();
                              },
                      child:
                          isSaving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _editBookDialog(DocumentSnapshot book) async {
    final data = book.data() as Map<String, dynamic>;
    final titleController = TextEditingController(text: data['title']);
    final authorController = TextEditingController(text: data['author']);
    final priceController = TextEditingController(
      text: data['price'].toString(),
    );
    final editionController = TextEditingController(text: data['edition']);
    String? selectedCategory = data['category'];
    String? selectedLocation = data['location'];

    final List<String> locations = [
      'Lefkoşa',
      'Gazimağusa',
      'Girne',
      'Güzelyurt',
      'İskele',
      'Lefke',
    ];

    final List<String> categories = [
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

    bool isSold = data['is_sold'] ?? false;
    String coverUrl = data['cover_url'];
    String coverPath = data['cover_path'] ?? '';
    _selectedImage = null;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Edit Book'),
                  content: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Book Name',
                          ),
                        ),
                        TextField(
                          controller: authorController,
                          decoration: const InputDecoration(
                            labelText: 'Author',
                          ),
                        ),
                        TextField(
                          controller: editionController,
                          decoration: const InputDecoration(
                            labelText: 'Edition',
                          ),
                        ),
                        TextField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price (₺)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Sold:'),
                            Checkbox(
                              value: isSold,
                              onChanged: (value) {
                                setState(() {
                                  isSold = value ?? false;
                                });
                              },
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await _pickImage();
                            setState(() {});
                          },
                          child: const Text('Change Cover Image'),
                        ),
                        if (_selectedImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_selectedImage!, height: 100),
                          ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedCategory,
                          items:
                              categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedLocation,
                          items:
                              locations.map((location) {
                                return DropdownMenuItem(
                                  value: location,
                                  child: Text(location),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedLocation = value;
                            });
                          },
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
                        if (_selectedImage != null) {
                          final uploadResult = await _uploadImage(
                            _selectedImage!,
                          );
                          coverUrl = uploadResult['cover_url']!;
                          coverPath = uploadResult['cover_path']!;
                        }

                        await FirebaseFirestore.instance
                            .collection('market_books')
                            .doc(book.id)
                            .update({
                              'title': titleController.text.trim(),
                              'author': authorController.text.trim(),
                              'edition': editionController.text.trim(),
                              'is_sold': isSold,
                              'price': double.tryParse(priceController.text),
                              'cover_url': coverUrl,
                              'cover_path': coverPath,
                              'approved': false,
                            });

                        Navigator.pop(context);
                        fetchMyBooks();
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _deleteBook(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('market_books')
          .doc(docId)
          .delete();
      fetchMyBooks();
    } catch (e) {
      debugPrint('❌ Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'My Books',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        foregroundColor: Colors.black,
        elevation: 2,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('market_books')
                .where('owner_id', isEqualTo: user.uid)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final myBooks = snapshot.data!.docs;

          if (myBooks.isEmpty) {
            return const Center(
              child: Text(
                'No books have been added yet.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myBooks.length,
            itemBuilder: (context, index) {
              final book = myBooks[index];
              final data = book.data() as Map<String, dynamic>;

              final title = data['title'] ?? 'No Title';
              final author = data['author'] ?? 'Unknown';
              final price = data['price'] ?? 0.0;
              final coverUrl = data['cover_url'] ?? '';
              final edition = data['edition'] ?? '';
              final isSold = data['is_sold'] ?? false;
              final isApproved = data['approved'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      child: Image.network(
                        coverUrl.isNotEmpty
                            ? coverUrl
                            : 'https://via.placeholder.com/90x120.png?text=No+Image',
                        width: 90,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Author: $author',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'Edition: $edition',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Status: ${isSold ? 'Sold' : 'Available'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isSold ? Colors.red : Colors.green,
                              ),
                            ),
                            Text(
                              '$price ₺',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isApproved ? Colors.green : Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isApproved
                                    ? '✔ Available in the Market'
                                    : '⏳ Pending Approval',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editBookDialog(book),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteBook(book.id),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _addBookDialog,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add),
        tooltip: 'Add Book',
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
            IconButton(icon: const Icon(Icons.menu_book), onPressed: () {}),
            const SizedBox(width: 48),
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MarketPage()),
                );
              },
            ),
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
