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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.library_add, color: Colors.indigo),
                      SizedBox(width: 8),
                      Text('Add New Book'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        _buildTextField(
                          titleController,
                          'Book Name',
                          Icons.book,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          authorController,
                          'Author',
                          Icons.person,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          editionController,
                          'Edition',
                          Icons.numbers,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          priceController,
                          'Price (₺)',
                          Icons.money,
                          isNumber: true,
                        ),

                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _pickImage();
                            setState(() {});
                          },
                          icon: const Icon(Icons.image, color: Colors.white),
                          label: const Text(
                            'Select Cover Image',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_selectedImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_selectedImage!, height: 140),
                          ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: _dropdownDecoration('Category'),
                          value: selectedCategory,
                          items:
                              categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                          onChanged:
                              (value) =>
                                  setState(() => selectedCategory = value),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          decoration: _dropdownDecoration('Location'),
                          value: selectedLocation,
                          items:
                              locations.map((location) {
                                return DropdownMenuItem(
                                  value: location,
                                  child: Text(location),
                                );
                              }).toList(),
                          onChanged:
                              (value) =>
                                  setState(() => selectedLocation = value),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
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
                                  'acquired_via': 'manual',
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
                              : const Text(
                                'Save',
                                style: TextStyle(color: Colors.white),
                              ),
                    ),
                  ],
                ),
          ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        backgroundColor: Colors.white70,
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

          final rawBooks = snapshot.data!.docs;
          final userId = user.uid;

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: enrichBooksWithAcquisitionInfo(rawBooks, userId),
            builder: (context, enrichedSnapshot) {
              if (!enrichedSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final myBooks = enrichedSnapshot.data!;

              if (myBooks.isEmpty) {
                return const Center(
                  child: Text(
                    'No books have been added yet.',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: myBooks.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final book = myBooks[index];
                    return _buildBookCard(book);
                  },
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

  Future<String> getAcquisitionType(String bookId, String currentUserId) async {
    final firestore = FirebaseFirestore.instance;

    // Purchase kontrolü
    final purchaseQuery =
        await firestore
            .collection('successful_purchases')
            .where('book_id', isEqualTo: bookId)
            .where('buyer_id', isEqualTo: currentUserId)
            .limit(1)
            .get();

    if (purchaseQuery.docs.isNotEmpty) return 'purchase';

    // Swap kontrolü
    final swapQuery =
        await firestore
            .collection('successful_swaps')
            .where('requested_book_id', isEqualTo: bookId)
            .where('accepted_by', isEqualTo: currentUserId)
            .limit(1)
            .get();

    if (swapQuery.docs.isNotEmpty) return 'swap';

    return 'manual'; // Kendisi eklemişse
  }

  Future<List<Map<String, dynamic>>> enrichBooksWithAcquisitionInfo(
    List<QueryDocumentSnapshot> books,
    String currentUserId,
  ) async {
    final enriched = <Map<String, dynamic>>[];

    for (final doc in books) {
      final data = doc.data() as Map<String, dynamic>;
      final bookId = doc.id;

      final acquiredVia = await getAcquisitionType(bookId, currentUserId);
      data['acquired_via'] = acquiredVia;

      enriched.add(data);
    }

    return enriched;
  }

  void _editBookDialogById(String bookId) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('market_books')
            .doc(bookId)
            .get();
    if (doc.exists) {
      await _editBookDialog(doc);
    }
  }

  Widget _buildBookCard(Map<String, dynamic> book) {
    final String? title = book['title'];
    final String? author = book['author'];
    final String? coverUrl = book['cover_url'];
    final double? price = book['price'];
    final String acquiredVia = book['acquired_via'] ?? 'manual';
    final isApproved = book['approved'] ?? false;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: NetworkImage(coverUrl ?? ''),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          // Cover image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(coverUrl ?? '', fit: BoxFit.cover),
            ),
          ),

          // Alt kısımdaki metinler
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title ?? 'Kitap',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'by ${author ?? ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (price != null)
                    Text(
                      '${price.toStringAsFixed(2)} ₺',
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Üst sağ köşedeki etiket
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: () {
                  if (acquiredVia == 'purchase') return Colors.blueAccent;
                  if (acquiredVia == 'swap') return Colors.orange;
                  return isApproved ? Colors.green : Colors.redAccent;
                }(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(() {
                if (acquiredVia == 'purchase') return 'Purchased';
                if (acquiredVia == 'swap') return 'Swapped';
                return isApproved ? 'Approved' : 'Waiting for approval';
              }(), style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildContinueSection(List<Map<String, dynamic>> books) {
    final swappedBooks =
        books.where((b) => b['acquired_via'] == 'swap').toList();

    if (swappedBooks.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Continue',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: swappedBooks.length,
            itemBuilder: (context, index) {
              final data = swappedBooks[index];
              return Container(
                width: 110,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        data['cover_url'] ?? '',
                        height: 100,
                        width: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        data['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'by ${data['author'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),

                    const Text(
                      'Swapped',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildManualSection(List<Map<String, dynamic>> books) {
    final manualBooks =
        books.where((b) => b['acquired_via'] == 'manual').toList();

    if (manualBooks.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Your Uploads',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 270, // daha yüksek
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: manualBooks.length,
            itemBuilder: (context, index) {
              final data = manualBooks[index];
              final isApproved = data['approved'] ?? false;

              return Container(
                width: 180,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: NetworkImage(data['cover_url'] ?? ''),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Üstte onay rozeti
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isApproved
                                  ? Colors.greenAccent.shade700
                                  : Colors.orange,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isApproved ? Icons.check_circle : Icons.schedule,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isApproved ? 'Onaylandı' : 'Bekliyor',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Alt bilgi alanı
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(20),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.9),
                              Colors.black.withOpacity(0.4),
                              Colors.transparent,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                ],
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'by ${data['author'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 2),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${data['price'] ?? 0} ₺',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.tealAccent,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 2),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                  ),
                                  onPressed:
                                      () =>
                                          _editBookDialogById(data['book_id']),
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => _deleteBook(data['book_id']),
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildPurchasedSection(List<Map<String, dynamic>> books) {
    final purchasedBooks =
        books.where((b) => b['acquired_via'] == 'purchase').toList();

    if (purchasedBooks.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Top Picks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: purchasedBooks.length,
            itemBuilder: (context, index) {
              final data = purchasedBooks[index];
              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(data['cover_url'] ?? ''),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 2),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'by ${data['author'] ?? ''}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Purchased',
                          style: TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
