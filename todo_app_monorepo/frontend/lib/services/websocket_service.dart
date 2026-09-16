import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

class WebSocketService {
  final String wsUrl;
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  String? _token;
  bool _isConnected = false;

  WebSocketService({required this.wsUrl});

  bool get isConnected => _isConnected;

  Stream<Map<String, dynamic>> get messageStream {
    if (_messageController == null) {
      _messageController = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _messageController!.stream;
  }

  Future<void> connect(String token) async {
    _token = token;
    try {
      final wsUri = Uri.parse('$wsUrl?token=$token');
      _channel = WebSocketChannel.connect(wsUri);

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            _messageController?.add(data);
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          print('WebSocket connection closed');
          // Attempt reconnect after delay
          Future.delayed(const Duration(seconds: 3), () {
            if (_token != null) {
              connect(_token!);
            }
          });
        },
        onError: (error) {
          _isConnected = false;
          print('WebSocket error: $error');
        },
      );

      _isConnected = true;
      print('WebSocket connected');
    } catch (e) {
      _isConnected = false;
      print('Failed to connect to WebSocket: $e');
      // Retry connection
      Future.delayed(const Duration(seconds: 3), () {
        if (_token != null) {
          connect(_token!);
        }
      });
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _token = null;
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }
}
