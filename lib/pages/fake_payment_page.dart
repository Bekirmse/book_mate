// ignore_for_file: use_build_context_synchronously, file_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FakePaymentPage extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final double bookPrice;
  final String currentOwnerId;

  const FakePaymentPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.bookPrice,
    required this.currentOwnerId,
  });

  @override
  State<FakePaymentPage> createState() => _FakePaymentPageState();
}

class _FakePaymentPageState extends State<FakePaymentPage> {
  final cardNumberController = TextEditingController();
  final expiryController = TextEditingController();
  final cvvController = TextEditingController();
  final zipController = TextEditingController();
  String selectedCountry = 'Turkey';
  bool saveCard = false;
  bool isProcessing = false;
  String? cardError;
  String? expiryError;
  String? cvvError;
  String? zipError;

  Future<void> _processPayment() async {
    setState(() {
      cardError = null;
      expiryError = null;
      cvvError = null;
      zipError = null;
    });

    final cardNumber = cardNumberController.text.trim();
    final expiry = expiryController.text.trim();
    final cvv = cvvController.text.trim();
    final zip = zipController.text.trim();

    bool hasError = false;

    if (cardNumber.isEmpty) {
      setState(() => cardError = "Kart numarası girin.");
      hasError = true;
    } else if (cardNumber.length != 16 ||
        !RegExp(r'^\d{16}$').hasMatch(cardNumber)) {
      setState(() => cardError = "Kart numarası 16 haneli olmalıdır.");
      hasError = true;
    }

    if (expiry.isEmpty) {
      setState(() => expiryError = "Son kullanma tarihi girin.");
      hasError = true;
    } else if (!RegExp(r'^(0[1-9]|1[0-2])\/?([0-9]{2})$').hasMatch(expiry)) {
      setState(() => expiryError = "Geçerli bir tarih girin (MM/YY).");
      hasError = true;
    }

    if (cvv.isEmpty) {
      setState(() => cvvError = "CVC girin.");
      hasError = true;
    } else if (cvv.length < 3 ||
        cvv.length > 4 ||
        !RegExp(r'^\d{3,4}$').hasMatch(cvv)) {
      setState(() => cvvError = "CVC 3 veya 4 haneli olmalıdır.");
      hasError = true;
    }

    if (zip.isEmpty) {
      setState(() => zipError = "Posta kodu girin.");
      hasError = true;
    } else if (!RegExp(r'^\d{4,6}$').hasMatch(zip)) {
      setState(() => zipError = "Geçerli bir posta kodu girin.");
      hasError = true;
    }

    if (hasError) return;

    setState(() => isProcessing = true);

    final buyer = FirebaseAuth.instance.currentUser;
    if (buyer == null) return;

    await FirebaseFirestore.instance
        .collection('market_books')
        .doc(widget.bookId)
        .update({
          'owner_id': buyer.uid,
          'owner_name': buyer.displayName ?? 'User',
          'approved': false,
        });

    await FirebaseFirestore.instance.collection('successful_purchases').add({
      'book_id': widget.bookId,
      'buyer_id': buyer.uid,
      'seller_id': widget.currentOwnerId,
      'timestamp': Timestamp.now(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "‘${widget.bookTitle}’ adlı kitabı ${widget.bookPrice} ₺ karşılığında satın aldınız.",
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Purchase",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        centerTitle: true,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Icon(Icons.credit_card, size: 48, color: Colors.indigo),
                  const SizedBox(height: 12),
                  Text(
                    "Secure Payment",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            /// Book & Price summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      widget.bookTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    "${widget.bookPrice.toStringAsFixed(2)} ₺",
                    style: const TextStyle(fontSize: 16, color: Colors.green),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            /// Card Info Fields
            Text(
              "Card Information",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: cardNumberController,
              label: "Card Number",
              hint: "1234 5678 9012 3456",
              maxLength: 16,
              prefixIcon: Icons.credit_card,
              keyboardType: TextInputType.number,
              errorText: cardError,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: expiryController,
                    label: "Expiry",
                    hint: "MM/YY",
                    keyboardType: TextInputType.datetime,
                    errorText: expiryError,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: cvvController,
                    label: "CVC",
                    hint: "123",
                    keyboardType: TextInputType.number,
                    errorText: cvvError,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text(
              "Billing Address",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: selectedCountry,
              items:
                  ["Turkey", "United States", "Germany", "France"]
                      .map(
                        (country) => DropdownMenuItem(
                          value: country,
                          child: Text(country),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) =>
                      setState(() => selectedCountry = value ?? 'Turkey'),
              decoration: const InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: zipController,
              label: "ZIP Code",
              hint: "34000",
              keyboardType: TextInputType.number,
              errorText: zipError,
            ),
            const SizedBox(height: 16),

            CheckboxListTile(
              title: const Text("Save card for future BookMate purchases"),
              value: saveCard,
              onChanged: (val) => setState(() => saveCard = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 28),

            /// Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isProcessing ? null : _processPayment,
                icon:
                    isProcessing
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.lock),
                label: Text(
                  isProcessing
                      ? "Processing..."
                      : "Pay ${widget.bookPrice.toStringAsFixed(2)} ₺",
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  String? hint,
  IconData? prefixIcon,
  int? maxLength,
  TextInputType? keyboardType,
  String? errorText,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLength: maxLength,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      counterText: "",
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.white,
    ),
  );
}
