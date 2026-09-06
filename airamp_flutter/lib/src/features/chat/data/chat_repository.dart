import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatRepository {
  final String baseUrl;
  WebSocketChannel? _channel;

  ChatRepository({this.baseUrl = 'ws://localhost:8787/v1/chat/ws'});

  Stream<Map<String, dynamic>> connect(String userId, String token) {
    final uri = Uri.parse('$baseUrl?userId=$userId&token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);

      return _channel!.stream.map((event) {
        if (event is String) {
          return jsonDecode(event) as Map<String, dynamic>;
        }
        return {};
      });
    } catch (e) {
      // Return an empty stream or error stream if connection fails
      return const Stream.empty();
    }
  }

  void sendMessage(String conversationId, String text) {
    if (_channel != null) {
      final payload = jsonEncode({
        'type': 'send_message',
        'conversationId': conversationId,
        'text': text,
      });
      _channel!.sink.add(payload);
    }
  }

  void sendTypingIndicator(String conversationId) {
    if (_channel != null) {
      final payload = jsonEncode({
        'type': 'typing',
        'conversationId': conversationId,
      });
      _channel!.sink.add(payload);
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
