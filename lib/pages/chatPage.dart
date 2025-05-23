// ignore_for_file: file_names, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String bookTitle;

  const ChatPage({
    super.key,
    required this.receiverId,
    required this.bookTitle,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController messageController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  String receiverName = '';
  String senderName = '';

  @override
  void initState() {
    super.initState();
    fetchUserNames();
  }

  Future<void> fetchUserNames() async {
    final receiverDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.receiverId)
            .get();
    final senderDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

    if (mounted) {
      setState(() {
        receiverName = receiverDoc['fullName'] ?? 'Receiver';
        senderName = senderDoc['fullName'] ?? 'Sender';
        FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
      });
    }
  }

  void sendMessage() async {
    if (messageController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('messages').add({
      'senderId': user!.uid,
      'receiverId': widget.receiverId,
      'senderName': senderName,
      'receiverName': receiverName,
      'message': messageController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
    });

    messageController.clear();
  }

  Future<void> markMessagesAsSeen(List<DocumentSnapshot> docs) async {
    for (var doc in docs) {
      if (doc['receiverId'] == user!.uid && doc['seen'] == false) {
        await doc.reference.update({'seen': true});
      }
    }
  }

  Future<void> deleteMessagePrompt(DocumentSnapshot doc) async {
    final result = await showDialog<String>(
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
                Icon(Icons.delete_outline, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Delete Message',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: const Text(
              'Do you want to delete this message?',
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, 'me'),
                icon: const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: Colors.orange,
                ),
                label: const Text(
                  'Remove for Me',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, 'all'),
                icon: const Icon(
                  Icons.public_off,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Remove for Everyone',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
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

    if (result == 'all') {
      await doc.reference.delete();
    } else if (result == 'me') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removing only for yourself is not supported yet.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('messages')
              .orderBy('timestamp')
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No messages yet."));
        }

        final allMessages = snapshot.data!.docs;
        final messages =
            allMessages.where((doc) {
              final sender = doc['senderId'];
              final receiver = doc['receiverId'];
              return (sender == user!.uid && receiver == widget.receiverId) ||
                  (sender == widget.receiverId && receiver == user!.uid);
            }).toList();

        markMessagesAsSeen(messages);

        return ListView.builder(
          itemCount: messages.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isMe = msg['senderId'] == user!.uid;
            final name = msg['senderName'] ?? '';
            final seen = msg['seen'] ?? false;
            final timestamp = msg['timestamp'] as Timestamp?;
            final formattedTime =
                timestamp != null
                    ? DateFormat('HH:mm').format(timestamp.toDate())
                    : '';

            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: GestureDetector(
                onLongPress: isMe ? () => deleteMessagePrompt(msg) : null,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 12,
                  ),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.indigo[100] : Colors.grey[100],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isMe ? 12 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              seen ? Icons.done_all : Icons.check,
                              size: 16,
                              color: seen ? Colors.blue : Colors.grey,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        msg['message'],
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(widget.bookTitle, style: const TextStyle(fontSize: 16)),
            if (receiverName.isNotEmpty)
              Text(
                receiverName,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
            const SizedBox(height: 16),
          ],
        ),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Expanded(child: buildMessageList()),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: sendMessage,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32), // 👈 Alt boşluk eklendi
        ],
      ),
    );
  }
}
