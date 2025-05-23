// ignore_for_file: file_names, use_build_context_synchronously, deprecated_member_use

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
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 2,
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
          final relevantMessages =
              allMessages.where((msg) {
                return msg['senderId'] == userId || msg['receiverId'] == userId;
              }).toList();

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
            return const Center(
              child: Text(
                "There is no conversation yet.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: uniqueConversations.length,
            itemBuilder: (context, index) {
              final entry = uniqueConversations.entries.elementAt(index);
              final otherUserId = entry.key;
              final name = entry.value['name'];
              final bookTitle = entry.value['bookTitle'];
              final lastMessage = entry.value['lastMessage'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.indigo,
                    child: Text(
                      name.toString()[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bookTitle.isNotEmpty)
                        Text(
                          bookTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: Colors.grey,
                  ),
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
            },
          );
        },
      ),
    );
  }
}
