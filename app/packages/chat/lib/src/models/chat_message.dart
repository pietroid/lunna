import 'package:equatable/equatable.dart';

/// Who wrote a message.
enum MessageRole {
  /// The person using the app.
  user,

  /// The agent answering them.
  agent,

  /// A system-generated message (e.g. cancellation notice).
  system;

  /// Parses the role as the API spells it, defaulting to [agent].
  static MessageRole fromJson(String? value) {
    return switch (value) {
      'user' => MessageRole.user,
      'agent' => MessageRole.agent,
      'system' => MessageRole.system,
      _ => MessageRole.agent,
    };
  }
}

/// Whether a message carries plain text or an A2UI component tree.
enum MessageContentType {
  /// Plain text written by the user or a legacy agent reply.
  text,

  /// A2UI component tree rendered by the agent.
  a2ui;

  /// Parses the content type from the API, defaulting to [text].
  static MessageContentType fromJson(String? value) {
    return value == 'a2ui' ? MessageContentType.a2ui : MessageContentType.text;
  }
}

/// A2UI component node.
class A2uiComponent extends Equatable {
  /// {@macro a2ui_component}
  const A2uiComponent({
    required this.component,
    this.children,
    this.properties = const {},
  });

  /// Creates an [A2uiComponent] from JSON.
  factory A2uiComponent.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'] as List<dynamic>?;

    return A2uiComponent(
      component: json['component'] as String? ?? 'Text',
      children: rawChildren
          ?.map((c) => A2uiComponent.fromJson(c as Map<String, dynamic>))
          .toList(),
      properties: Map<String, dynamic>.from(json)
        ..remove('component')
        ..remove('children'),
    );
  }

  /// The component name, e.g. "Text", "Column", "AppButton".
  final String component;

  /// Child components, when the component is a layout host.
  final List<A2uiComponent>? children;

  /// All other component properties (text, action, variant, etc.).
  final Map<String, dynamic> properties;

  /// Convenience accessor for the action property.
  Map<String, dynamic>? get action {
    final raw = properties['action'];
    if (raw is Map<String, dynamic>) return raw;
    return null;
  }

  @override
  List<Object?> get props => [component, children, properties];
}

/// Extra metadata attached to a message.
class ChatMessageMetadata extends Equatable {
  /// {@macro chat_message_metadata}
  const ChatMessageMetadata({
    required this.contentType,
    this.a2ui,
    this.model,
    this.latencyMs,
    this.traceId,
  });

  /// Creates metadata from the API's JSON.
  factory ChatMessageMetadata.fromJson(Map<String, dynamic> json) {
    final rawA2ui = json['a2ui'] as Map<String, dynamic>?;

    return ChatMessageMetadata(
      contentType: MessageContentType.fromJson(json['contentType'] as String?),
      a2ui: rawA2ui != null ? A2uiComponent.fromJson(rawA2ui) : null,
      model: json['model'] as String?,
      latencyMs: json['latencyMs'] as int?,
      traceId: json['traceId'] as String?,
    );
  }

  /// Whether the message body is plain text or an A2UI tree.
  final MessageContentType contentType;

  /// The parsed A2UI tree, when [contentType] is [MessageContentType.a2ui].
  final A2uiComponent? a2ui;

  /// The model that generated an agent message.
  final String? model;

  /// Time spent generating the reply, in milliseconds.
  final int? latencyMs;

  /// The turn this message belongs to, matching the server and agent logs.
  final String? traceId;

  @override
  List<Object?> get props => [
    contentType,
    a2ui,
    model,
    latencyMs,
    traceId,
  ];
}

/// {@template chat_message}
/// A single turn in a thread.
/// {@endtemplate}
class ChatMessage extends Equatable {
  /// {@macro chat_message}
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.metadata,
  });

  /// Creates a [ChatMessage] from the API's JSON.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'] as Map<String, dynamic>?;

    return ChatMessage(
      id: json['id'] as String? ?? '',
      role: MessageRole.fromJson(json['role'] as String?),
      text: json['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      metadata: rawMetadata != null
          ? ChatMessageMetadata.fromJson(rawMetadata)
          : null,
    );
  }

  /// A message the user has typed but the server has not acknowledged yet.
  ///
  /// Carries a local id so the optimistic copy can be told apart from the one
  /// that comes back, and is otherwise an ordinary message.
  factory ChatMessage.pending(String text) {
    final now = DateTime.now();
    return ChatMessage(
      id: 'pending-${now.microsecondsSinceEpoch}',
      role: MessageRole.user,
      text: text,
      createdAt: now,
    );
  }

  /// Stable id, derived by the server from the role and timestamp.
  final String id;

  /// Who wrote the message.
  final MessageRole role;

  /// The raw message body.
  final String text;

  /// When the message was written, in local time.
  final DateTime createdAt;

  /// Optional metadata, including A2UI content and tool calls.
  final ChatMessageMetadata? metadata;

  /// Whether this message came from the person using the app.
  bool get isUser => role == MessageRole.user;

  /// Whether this message carries an A2UI component tree.
  bool get isA2ui => metadata?.contentType == MessageContentType.a2ui;

  @override
  List<Object?> get props => [id, role, text, createdAt, metadata];
}
