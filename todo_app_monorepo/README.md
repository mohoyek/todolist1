# ToDoList Application - Full Stack Dart/Flutter Monorepo

A complete, networked ToDoList application built with a monorepo structure featuring:
- **Frontend**: Flutter with Material 3 design and Riverpod state management
- **Backend**: Dart Shelf HTTP server with WebSocket support
- **Database**: SQLite for persistent storage
- **Authentication**: JWT-based internal auth
- **Real-time Sync**: WebSocket for instant UI updates

## Project Structure

```
todo_app_monorepo/
├── backend/
│   ├── bin/
│   │   └── server.dart          # Server entry point
│   ├── src/
│   │   ├── db/
│   │   │   └── database.dart    # SQLite schema & initialization
│   │   ├── handlers/
│   │   │   └── websocket_handler.dart  # WebSocket broadcast service
│   │   ├── models/
│   │   │   └── models.dart      # Backend data models
│   │   └── routes/
│   │       ├── api_routes.dart  # Main API router
│   │       ├── auth_routes.dart # Authentication endpoints
│   │       ├── task_routes.dart # Task CRUD operations
│   │       └── category_routes.dart # Category CRUD operations
│   └── pubspec.yaml
│
└── frontend/
    └── lib/
        ├── main.dart            # App entry point
        ├── models/
        │   └── models.dart      # Frontend data models
        ├── providers/
        │   └── providers.dart   # Riverpod providers
        ├── services/
        │   ├── api_service.dart # HTTP API client
        │   └── websocket_service.dart # WebSocket client
        └── ui/
            ├── screens/
            │   ├── auth_wrapper.dart
            │   ├── login_screen.dart
            │   ├── register_screen.dart
            │   └── dashboard_screen.dart
            └── widgets/
                ├── task_card.dart
                └── task_bottom_sheet.dart
    └── pubspec.yaml
```

## Features

### User Management
- Register new users with username/password
- Login with JWT token authentication
- Token persistence using SharedPreferences

### Task Management
- Create, edit, delete tasks
- Mark tasks as complete/incomplete
- Pin important tasks to top of list
- Drag & drop reordering (persists in DB)
- Assign tasks to other users
- Set due dates with Persian (Jalali/Shamsi) calendar

### Categories
- Create custom categories with colors
- Filter tasks by category
- Default categories created on user registration

### Real-time Sync
- WebSocket connection for instant updates
- Changes broadcast to all connected clients
- Automatic reconnection on disconnect

### UI/UX
- Material 3 design with dynamic color schemes
- Beautiful animations and transitions
- Persian calendar integration
- RTL support for Persian language
- Dark/Light theme support

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `GET /api/auth/me` - Get current user info

### Users
- `GET /api/users` - Get all users (for assignment)

### Categories
- `GET /api/categories` - Get user's categories
- `POST /api/categories` - Create category
- `PUT /api/categories/:id` - Update category
- `DELETE /api/categories/:id` - Delete category

### Tasks
- `GET /api/tasks` - Get all tasks (optionally filtered by category)
- `POST /api/tasks` - Create task
- `PUT /api/tasks/:id` - Update task
- `PATCH /api/tasks/:id/toggle-complete` - Toggle completion
- `PATCH /api/tasks/:id/toggle-pin` - Toggle pinned status
- `POST /api/tasks/reorder` - Reorder tasks
- `DELETE /api/tasks/:id` - Delete task

### WebSocket
- `WS /ws` - Real-time sync endpoint

## Running the Application

### Prerequisites
- Dart SDK >= 3.0.0
- Flutter SDK >= 3.0.0

### Backend Setup

```bash
cd backend
dart pub get
dart run bin/server.dart --port 8080 --host localhost
```

The server will start on `http://localhost:8080` with WebSocket at `ws://localhost:8080/ws`.

### Frontend Setup

```bash
cd frontend
flutter pub get
flutter run
```

## Database

SQLite database is stored at `backend/data/todo_app.db`. The schema includes:
- `users` table: User accounts
- `categories` table: Task categories with colors
- `tasks` table: Tasks with all metadata

## Security Notes

⚠️ **For Development Only**: This implementation uses a simple JWT secret key. For production:
- Use environment variables for secrets
- Implement proper password policies
- Add rate limiting
- Use HTTPS/WSS
- Implement refresh tokens

## Tech Stack

| Component | Technology |
|-----------|------------|
| Frontend | Flutter + Material 3 |
| State Management | Riverpod |
| Backend | Dart Shelf |
| Database | SQLite3 |
| Auth | JWT (dart_jsonwebtoken) |
| Real-time | WebSockets |
| Calendar | persian_datetime_picker, shamsi_date |
| Fonts | Google Fonts (Vazirmatn) |

## License

MIT License
