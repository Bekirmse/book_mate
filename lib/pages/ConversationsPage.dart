// ignore_for_file: file_names, use_build_context_synchronously

import 'package:book_mate/pages/chatPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ConversationsPage extends StatelessWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Conversations",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allMessages = snapshot.data!.docs;

          // Kullanıcının katıldığı tüm mesajları filtrele
          final relevantMessages =
              allMessages.where((msg) {
                return msg['senderId'] == userId || msg['receiverId'] == userId;
              }).toList();

          // Her karşı kullanıcıyla yalnızca bir konuşmayı listele
          final uniqueConversations = <String, Map<String, dynamic>>{};

          for (var msg in relevantMessages) {
            final isSentByMe = msg['senderId'] == userId;
            final otherUserId =
                isSentByMe ? msg['receiverId'] : msg['senderId'];
            final otherUserName =
                isSentByMe
                    ? msg['receiverName'] ?? 'Receiver'
                    : msg['senderName'] ?? 'Sender';

            if (!uniqueConversations.containsKey(otherUserId)) {
              uniqueConversations[otherUserId] = {
                'name': otherUserName,
                'bookTitle':
                    msg.data().toString().contains('bookTitle')
                        ? msg['bookTitle']
                        : '',
                'lastMessage': msg['message'],
              };
            }
          }

          if (uniqueConversations.isEmpty) {
            return const Center(child: Text("There is no conversation yet."));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children:
                uniqueConversations.entries.map((entry) {
                  final otherUserId = entry.key;
                  final name = entry.value['name'];
                  final bookTitle = entry.value['bookTitle'];
                  final lastMessage = entry.value['lastMessage'];

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo,
                        child: Text(name.toString()[0].toUpperCase()),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (bookTitle.isNotEmpty)
                            Text(
                              bookTitle,
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ChatPage(
                                  receiverId: otherUserId,
                                  bookTitle: bookTitle,
                                ),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}
