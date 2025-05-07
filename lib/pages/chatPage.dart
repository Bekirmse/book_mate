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
        receiverName = receiverDoc['fullName'] ?? 'Alıcı';
        senderName = senderDoc['fullName'] ?? 'Gönderici';
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
            title: const Text('Mesajı sil'),
            content: const Text('Bu mesajı silmek istiyor musunuz?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'me'),
                child: const Text('Benden Sil'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'all'),
                child: const Text('Herkesten Sil'),
              ),
            ],
          ),
    );

    if (result == 'all') {
      await doc.reference.delete();
    } else if (result == 'me') {
      // Benden sil özelliği için mesajların kullanıcıya özel gösterimi yapılmalı (uygulanmadı)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sadece kendinizden silme henüz desteklenmiyor.'),
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
          return const Center(child: Text("Henüz mesaj yok."));
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
                    color: isMe ? Colors.indigo[100] : Colors.grey[200],
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
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        msg['message'],
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Icon(
                              seen ? Icons.done_all : Icons.check,
                              size: 16,
                              color: seen ? Colors.blue : Colors.grey,
                            ),
                          ],
                        ],
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
      appBar: AppBar(title: Text(widget.bookTitle)),
      body: Column(
        children: [
          Expanded(child: buildMessageList()),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ), // Yüksekliği biraz azalttım
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'Write your message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
          const Divider(height: 30),
        ],
      ),
    );
  }
}
