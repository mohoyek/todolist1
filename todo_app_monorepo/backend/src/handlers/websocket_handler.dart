import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../db/database.dart';
import '../models/models.dart';

/// WebSocket broadcast service for real-time updates
class WebSocketBroadcastService {
  static final WebSocketBroadcastService _instance = WebSocketBroadcastService._internal();
  final Set<WebSocketChannel> _clients = {};
  final Map<WebSocketChannel, String> _clientUserIds = {}; // Map client to user ID

  factory WebSocketBroadcastService() {
    return _instance;
  }

  WebSocketBroadcastService._internal();

  /// Add a client to the broadcast list
  void addClient(WebSocketChannel client, String userId) {
    _clients.add(client);
    _clientUserIds[client] = userId;
    
    // Send welcome message with current state
    client.sink.add(jsonEncode({
      'type': 'connected',
      'message': 'Connected to real-time sync',
    }));
    
    print('Client connected: $userId (Total clients: ${_clients.length})');
  }

  /// Remove a client from the broadcast list
  void removeClient(WebSocketChannel client) {
    _clients.remove(client);
    _clientUserIds.remove(client);
    print('Client disconnected (Remaining clients: ${_clients.length})');
  }

  /// Broadcast a message to all connected clients
  void broadcast(Map<String, dynamic> message) {
    final encodedMessage = jsonEncode(message);
    
    final clientsToRemove = <WebSocketChannel>[];
    
    for (final client in _clients) {
      try {
        client.sink.add(encodedMessage);
      } catch (e) {
        // Client is no longer available, mark for removal
        clientsToRemove.add(client);
      }
    }
    
    // Remove failed clients
    for (final client in clientsToRemove) {
      removeClient(client);
    }
  }

  /// Broadcast to all clients except the sender
  void broadcastExcept(WebSocketChannel sender, Map<String, dynamic> message) {
    final encodedMessage = jsonEncode(message);
    
    final clientsToRemove = <WebSocketChannel>[];
    
    for (final client in _clients) {
      if (client != sender) {
        try {
          client.sink.add(encodedMessage);
        } catch (e) {
          clientsToRemove.add(client);
        }
      }
    }
    
    for (final client in clientsToRemove) {
      removeClient(client);
    }
  }

  /// Broadcast to clients of a specific user
  void broadcastToUser(String userId, Map<String, dynamic> message) {
    final encodedMessage = jsonEncode(message);
    
    final clientsToRemove = <WebSocketChannel>[];
    
    for (final entry in _clientUserIds.entries) {
      if (entry.value == userId) {
        try {
          entry.key.sink.add(encodedMessage);
        } catch (e) {
          clientsToRemove.add(entry.key);
        }
      }
    }
    
    for (final client in clientsToRemove) {
      removeClient(client);
    }
  }

  /// Get count of connected clients
  int get clientCount => _clients.length;

  /// Get all connected user IDs
  List<String> get connectedUserIds => _clientUserIds.values.toList();
}

/// Create WebSocket handler for real-time task synchronization
Handler createWebSocketHandler() {
  final broadcastService = WebSocketBroadcastService();
  final dbHelper = DatabaseHelper();

  return webSocketHandler((WebSocketChannel channel, String? path) {
    String? authenticatedUserId;

    channel.stream.listen((message) {
      try {
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        final type = data['type'] as String?;

        switch (type) {
          case 'auth':
            // Authenticate WebSocket connection with JWT token
            final token = data['token'] as String?;
            if (token != null) {
              // Verify token (simplified - in production use proper JWT verification)
              final db = dbHelper.database;
              // Extract user_id from token payload (simplified)
              // In production, properly decode JWT
              final result = db.select('SELECT id FROM users LIMIT 1');
              if (result.isNotEmpty) {
                authenticatedUserId = result.first['id'] as String;
                broadcastService.addClient(channel, authenticatedUserId!);
                
                channel.sink.add(jsonEncode({
                  'type': 'auth_success',
                  'user_id': authenticatedUserId,
                }));
              }
            }
            break;

          case 'task_created':
          case 'task_updated':
          case 'task_deleted':
          case 'task_reordered':
          case 'task_pinned':
            // Broadcast task changes to all other clients
            if (authenticatedUserId != null) {
              broadcastService.broadcastExcept(channel, {
                'type': type,
                'data': data['data'],
                'timestamp': DateTime.now().toIso8601String(),
              });
            }
            break;
        }
      } catch (e) {
        print('Error processing WebSocket message: $e');
      }
    }, onDone: () {
      broadcastService.removeClient(channel);
    }, onError: (error) {
      print('WebSocket error: $error');
      broadcastService.removeClient(channel);
    });
  });
}
