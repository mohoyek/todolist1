import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import '../routes/api_routes.dart';
import '../handlers/websocket_handler.dart';

/// Main server entry point
Future<void> main(List<String> args) async {
  // Parse command line arguments for port
  int port = 8080;
  String host = 'localhost';
  
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--port' && i + 1 < args.length) {
      port = int.tryParse(args[i + 1]) ?? 8080;
    } else if (args[i] == '--host' && i + 1 < args.length) {
      host = args[i + 1];
    }
  }

  // Create the HTTP handler with API routes
  final httpHandler = createHandler();
  
  // Create WebSocket handler for real-time sync
  final wsHandler = createWebSocketHandler();

  // Combined handler that routes both HTTP and WebSocket requests
  Handler combinedHandler = (Request request) async {
    // Handle WebSocket upgrade requests
    if (request.url.path == '/ws') {
      return wsHandler(request);
    }
    
    // Handle regular HTTP requests
    return httpHandler(request);
  };

  // Start the server
  try {
    final server = await shelf_io.serve(
      combinedHandler,
      InternetAddress.anyIPv4,
      port,
    );

    print('');
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║           ToDoList Backend Server Started                 ║');
    print('╠═══════════════════════════════════════════════════════════╣');
    print('║  HTTP Server:   http://$host:$port                        ');
    print('║  WebSocket:     ws://$host:$port/ws                       ');
    print('║                                                           ');
    print('║  API Endpoints:                                           ');
    print('║    POST /api/auth/register  - Register new user           ');
    print('║    POST /api/auth/login     - Login user                  ');
    print('║    GET  /api/auth/me        - Get current user            ');
    print('║    GET  /api/users          - Get all users               ');
    print('║    GET  /api/categories     - Get categories              ');
    print('║    POST /api/categories     - Create category             ');
    print('║    PUT  /api/categories/:id - Update category             ');
    print('║    DELETE /api/categories/:id - Delete category           ');
    print('║    GET  /api/tasks          - Get tasks                   ');
    print('║    POST /api/tasks          - Create task                  ');
    print('║    PUT  /api/tasks/:id      - Update task                 ');
    print('║    PATCH /api/tasks/:id/toggle-complete - Toggle complete ');
    print('║    PATCH /api/tasks/:id/toggle-pin - Toggle pin           ');
    print('║    POST /api/tasks/reorder  - Reorder tasks               ');
    print('║    DELETE /api/tasks/:id    - Delete task                 ');
    print('╚═══════════════════════════════════════════════════════════╝');
    print('');
    print('Server running on http://$host:$port');
    print('Press Ctrl+C to stop the server.');
    
    // Handle server shutdown gracefully
    ProcessSignal.sigint.watch().listen((_) {
      print('\nShutting down server...');
      server.close();
      exit(0);
    });
    
  } catch (e) {
    print('Error starting server: $e');
    exit(1);
  }
}
