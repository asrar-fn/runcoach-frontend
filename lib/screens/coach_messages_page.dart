import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_storage_service.dart';
import '../config/api_config.dart'; // adjust path as needed

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

class CoachMessagesPage extends StatefulWidget {
  final String currentUserId;   // coach's Firebase UID
  final String athleteId;       // athlete's Firebase UID
  final String athleteName;     // for the AppBar title

  const CoachMessagesPage({
    Key? key,
    required this.currentUserId,
    required this.athleteId,
    required this.athleteName,
  }) : super(key: key);

  @override
  State<CoachMessagesPage> createState() => _CoachMessagesPageState();
}

class _CoachMessagesPageState extends State<CoachMessagesPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const Color _primary = Color(0xFF2575FC);
  static const Color _accent = Color(0xFFF7941D);
  static const String _baseUrl = '${ApiConfig.baseUrl}/api';

  List<Message> _conversation = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

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
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/messages/conversation/${widget.athleteId}'),
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
        // _markAsRead();
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } else {
        setState(() { _error = 'Failed to load messages'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error: $e'; _isLoading = false; });
    }
  }

  Future<void> _markAsRead() async {
    try {
      final token = await _getToken();
      await http.patch(
        Uri.parse('$_baseUrl/messages/read/${widget.athleteId}'),
        headers: { 'Authorization': 'Bearer $token' },
      );
    } catch (_) {}
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final optimisticMsg = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      fromId: widget.currentUserId,
      toId: widget.athleteId,
      text: text,
      createdAt: DateTime.now(),
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
        body: jsonEncode({ 'to': widget.athleteId, 'text': text }),
      );

      if (response.statusCode == 201) {
        final realMsg = Message.fromJson(jsonDecode(response.body));
        setState(() {
          final i = _conversation.indexWhere((m) => m.id == optimisticMsg.id);
          if (i != -1) _conversation[i] = realMsg;
        });
      } else {
        _removeOptimistic(optimisticMsg.id);
        _showError('Failed to send. Please try again.');
      }
    } catch (e) {
      _removeOptimistic(optimisticMsg.id);
      _showError('Error: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _removeOptimistic(String id) =>
      setState(() => _conversation.removeWhere((m) => m.id == id));

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
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
        leading: BackButton(color: Colors.black87),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              radius: 16,
              child: Text(
                widget.athleteName.isNotEmpty
                    ? widget.athleteName[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.athleteName,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Athlete',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          Expanded(child: _buildBody()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadMessages, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_conversation.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No messages yet.\nStart the conversation! 💬',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _conversation.length,
      itemBuilder: (context, index) => _buildBubble(_conversation[index]),
    );
  }

  Widget _buildBubble(Message message) {
    final isMe = message.fromId == widget.currentUserId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              radius: 16,
              child: Text(
                widget.athleteName.isNotEmpty ? widget.athleteName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? _primary : Colors.grey[100],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
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
                      color: isMe ? Colors.white : Colors.black87,
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
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.read ? Icons.done_all : Icons.done,
                        size: 13,
                        color: message.read ? _primary : Colors.grey,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _primary.withOpacity(0.15),
              radius: 16,
              child: const Text(
                'Me',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  hintText: 'Message ${widget.athleteName}...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
                  fillColor: Colors.grey[100],
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: _primary, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _handleSendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_primary, _accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                  width: 20, height: 20,
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

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}