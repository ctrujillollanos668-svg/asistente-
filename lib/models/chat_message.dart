enum ActionType {
  whatsapp,
  youtube,
  spotify,
  camera,
  maps,
  browser,
  dialer,
  email,
  generalApp,
  // ── Nuevas apps avanzadas ──
  instagram,
  facebook,
  tiktok,
  twitter,
  telegram,
  netflix,
  calculator,
  settings,
  gallery,
  clock,
  calendar,
  contacts,
  fileManager,
  notes,
  snapchat,
  pinterest,
  linkedin,
  uber,
  waze,
}

enum AuthorizationStatus {
  none,
  pending,
  granted,
  rejected,
}

class AppAction {
  final ActionType type;
  final String appName;
  final String packageName;
  final String? payload;
  final String description;

  AppAction({
    required this.type,
    required this.appName,
    required this.packageName,
    this.payload,
    required this.description,
  });
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final AppAction? action;
  AuthorizationStatus authorizationStatus;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.action,
    this.authorizationStatus = AuthorizationStatus.none,
  });
}
