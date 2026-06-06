import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_storage_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Message {
  final String id;
  final String fromId;
  final String toId;
  final String text;
  final DateTime createdAt;
  final bool read;

  Message({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.text,
    required this.createdAt,
    this.read = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      fromId: json['from'] ?? '',
      toId: json['to'] ?? '',
      text: json['text'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      read: json['read'] ?? false,
    );
  }
}

class MessagesPage extends StatefulWidget {
  final String currentUserId;
  final String coachId;

  const MessagesPage({
    Key? key,
    required this.currentUserId,
    required this.coachId,
  }) : super(key: key);

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color primaryBrandColor = const Color(0xFF2575FC);
  final Color secondaryBrandColor = const Color(0xFFF7941D);

  List<Message> _conversation = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  static const String _baseUrl = 'http://localhost:5000/api';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<String?> _getToken() async {
    final authData = await AuthStorageService.getAuthData();
    return authData['authToken'];
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _getToken();

      final response = await http.get(
        Uri.parse('$_baseUrl/messages/conversation/${widget.coachId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _conversation = data.map((e) => Message.fromJson(e)).toList();
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } else {
        setState(() {
          _error = 'Failed to load messages';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Optimistically add to UI immediately
    final optimisticMsg = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      fromId: widget.currentUserId,
      toId: widget.coachId,
      text: text,
      createdAt: DateTime.now(),
      read: false,
    );

    setState(() {
      _conversation.add(optimisticMsg);
      _isSending = true;
    });
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final token = await _getToken();

      final response = await http.post(
        Uri.parse('$_baseUrl/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to': widget.coachId,
          'text': text,
        }),
      );

      if (response.statusCode == 201) {
        // Replace optimistic message with real one from server
        final realMsg = Message.fromJson(jsonDecode(response.body));
        setState(() {
          final index = _conversation.indexWhere((m) => m.id == optimisticMsg.id);
          if (index != -1) {
            _conversation[index] = realMsg;
          }
        });
      } else {
        // Remove optimistic message on failure
        setState(() {
          _conversation.removeWhere((m) => m.id == optimisticMsg.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _conversation.removeWhere((m) => m.id == optimisticMsg.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Messages",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: _loadMessages,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.message, color: primaryBrandColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Conversation with your Coach",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Message List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2575FC)))
                : _error != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadMessages,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : _conversation.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "No messages yet.\nSay hello to your coach! 👋",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _conversation.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_conversation[index]);
              },
            ),
          ),

          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final bool fromCurrentUser = message.fromId == widget.currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment:
        fromCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!fromCurrentUser) ...[
            CircleAvatar(
              backgroundColor: primaryBrandColor,
              foregroundColor: Colors.white,
              radius: 16,
              child: const Text("C", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
              fromCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: fromCurrentUser ? primaryBrandColor : Colors.grey[100],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(fromCurrentUser ? 18 : 4),
                      bottomRight: Radius.circular(fromCurrentUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: fromCurrentUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    if (fromCurrentUser) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.read ? Icons.done_all : Icons.done,
                        size: 13,
                        color: message.read ? primaryBrandColor : Colors.grey,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (fromCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.grey[200],
              foregroundColor: Colors.black87,
              radius: 16,
              child: const Text("Me", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Message your coach...",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
                  fillColor: Colors.grey[100],
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide(color: primaryBrandColor, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _handleSendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primaryBrandColor, secondaryBrandColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryBrandColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isSending ? null : _handleSendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}