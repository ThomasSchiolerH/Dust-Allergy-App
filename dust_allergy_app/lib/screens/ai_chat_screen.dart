import 'package:flutter/material.dart';
import '../models/symptom_entry.dart';
import '../models/cleaning_entry.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';

class AIChatScreen extends StatefulWidget {
  final List<SymptomEntry> symptoms;
  final List<CleaningEntry> cleaning;

  const AIChatScreen({
    super.key,
    required this.symptoms,
    required this.cleaning,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();
  bool _hasShownOffTopicHint = false;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          content:
              'Hi there! I\'m your dust allergy assistant. I can help you with questions about dust allergies, symptoms, cleaning tips, and allergen management. How can I help you today?',
          role: 'assistant',
        ),
      );

      // Add suggestion message
      _messages.add(
        ChatMessage(
          content:
              'You can ask me questions like "How do I reduce dust mites in my bedroom?" or "What cleaning methods work best for dust allergies?"',
          role: 'hint',
        ),
      );
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    // Add user message to chat
    setState(() {
      _messages.add(ChatMessage(content: userMessage, role: 'user'));
      _isTyping = true;
    });

    // Scroll to bottom
    _scrollToBottom();

    try {
      // Convert messages to format expected by AI service
      final messageHistory = _messages
          .where((msg) => msg.role == 'user' || msg.role == 'assistant')
          .map((msg) => msg.toMap())
          .toList();

      // Get AI response
      final response = await AIService.chatWithAI(userMessage, messageHistory);

      // Check if it's an off-topic message
      final isOffTopicResponse = response.contains(
              'I can only answer questions related to dust allergies') ||
          response
              .contains('I can only provide information about dust allergies');

      setState(() {
        _messages.add(ChatMessage(content: response, role: 'assistant'));

        // If this was an off-topic question, add a hint message
        if (isOffTopicResponse && !_hasShownOffTopicHint) {
          _hasShownOffTopicHint = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            setState(() {
              _messages.add(ChatMessage(
                content:
                    'Try asking questions like "How can I reduce dust in my bedroom?" or "What cleaning methods help with dust allergies?"',
                role: 'hint',
              ));
              // Scroll to show the hint
              _scrollToBottom();
            });
          });
        }

        _isTyping = false;
      });

      // Scroll to bottom again to see response
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            content:
                'Sorry, I\'m having trouble connecting. Please try again later.',
            role: 'assistant',
          ),
        );
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat Assistant'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Medical disclaimer at the top
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.amber[800],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AIService.medicalDisclaimer,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('AI is typing',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          _buildInputField(),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    final isHint = message.role == 'hint';
    final theme = Theme.of(context);

    // Determine bubble color based on message type
    Color? bubbleColor;
    if (isUser) {
      bubbleColor = theme.colorScheme.primary.withOpacity(0.8);
    } else if (isHint) {
      bubbleColor = Colors.amber.withOpacity(0.2);
    } else {
      bubbleColor = theme.brightness == Brightness.dark
          ? Colors.grey[800]
          : Colors.grey[200];
    }

    final textColor = isUser
        ? Colors.white
        : isHint
            ? Colors.amber[900]
            : theme.textTheme.bodyMedium?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            CircleAvatar(
              backgroundColor: isHint
                  ? Colors.amber.withOpacity(0.2)
                  : theme.colorScheme.primary.withOpacity(0.2),
              radius: 16,
              child: Icon(
                isHint ? Icons.lightbulb_outline : Icons.assistant,
                size: 18,
                color: isHint ? Colors.amber[800] : theme.colorScheme.primary,
              ),
            ),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: EdgeInsets.only(
                left: isUser ? 50 : 0,
                right: isUser ? 0 : 50,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(color: textColor),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser)
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              radius: 16,
              child: const Icon(
                Icons.person,
                size: 18,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Ask about dust allergies...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
