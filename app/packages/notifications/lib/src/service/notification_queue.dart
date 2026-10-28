import 'package:app_ui/app_ui.dart' show AppBrand;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:l10n/l10n.dart';
import 'package:notifications/src/models/notification_answer.dart';
import 'package:timezone/timezone.dart' as tz;

/// Where a reminder's button chosen without opening the app is answered.
///
/// Must be a top-level or static function marked
/// `@pragma('vm:entry-point')`: the system runs it in an engine of its own,
/// with nothing of the app set up.
typedef BackgroundAction = void Function(NotificationResponse response);

/// The category of a reminder that asks, whose buttons answer it.
const askCategory = 'ask';

/// {@template queued_notification}
/// One reminder as the operating system's queue holds it.
/// {@endtemplate}
class QueuedNotification {
  /// {@macro queued_notification}
  const QueuedNotification({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.timeSensitive,
    required this.daily,
    required this.payload,
    this.asks = false,
  });

  /// The queue's own integer id.
  final int id;

  /// When it fires, on the wall clock of the user's calendar.
  final tz.TZDateTime fireAt;

  /// Final text.
  final String title;

  /// Final text.
  final String body;

  /// Whether it should break through a Focus mode.
  final bool timeSensitive;

  /// Whether it is one of the morning or evening reminders rather than a
  /// block's. Android files the two under separate channels.
  final bool daily;

  /// What comes back when it is tapped.
  final String payload;

  /// Whether it asks about a block, and so carries the buttons that answer
  /// it (on iOS; Android's come with #56).
  final bool asks;
}

/// The device's notification queue, reduced to what the scheduler needs.
///
/// An interface so the reconciliation can be tested without a platform
/// channel. [LocalNotificationQueue] is the one real implementation.
abstract interface class NotificationQueue {
  /// Sets the queue up, without asking for permission. [onTap] receives the
  /// payload of a reminder tapped while the app is running, and the id of
  /// the button when one that opens the app was chosen;
  /// [onBackgroundAction] answers the buttons that do not open it.
  Future<void> initialize({
    required void Function(String? payload, String? actionId) onTap,
    BackgroundAction? onBackgroundAction,
  });

  /// The reminder that launched the app, and the button that did, if one
  /// did.
  Future<({String? payload, String? actionId})?> launchResponse();

  /// Whether reminders may be shown at all.
  Future<bool> isPermitted();

  /// Asks the user, and answers whether they said yes.
  Future<bool> requestPermission();

  /// The ids of every reminder still waiting to fire.
  Future<Set<int>> pendingIds();

  /// Queues [notification].
  Future<void> schedule(QueuedNotification notification);

  /// Takes the reminder with [id] off the queue.
  Future<void> cancel(int id);
}

/// {@template local_notification_queue}
/// [NotificationQueue] over `flutter_local_notifications`.
///
/// The only code in the app that touches the plugin.
/// {@endtemplate}
class LocalNotificationQueue implements NotificationQueue {
  /// {@macro local_notification_queue}
  LocalNotificationQueue({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// The strings for the channels' names, which Android shows in the app's
  /// notification settings. Looked up without a [BuildContext], because
  /// the background refresh registers them from an isolate with no widgets.
  static final AppLocalizations _l10n = lookupAppLocalizations(
    const Locale('pt'),
  );

  static final _blocksChannel = AndroidNotificationChannel(
    'blocks',
    _l10n.notificationChannelBlocks,
    description: _l10n.notificationChannelBlocksDescription,
    importance: Importance.high,
  );

  static final _dailyChannel = AndroidNotificationChannel(
    'daily',
    _l10n.notificationChannelDaily,
    description: _l10n.notificationChannelDailyDescription,
  );

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// A reminder's three buttons, on iOS: Confirmar and +10 min answer
  /// without opening the app; talking it over opens it. Android draws none
  /// until #56, and its reminders open the app as before.
  static final _askCategory = DarwinNotificationCategory(
    askCategory,
    actions: [
      DarwinNotificationAction.plain(
        NotificationAction.confirm.id,
        _l10n.notificationActionConfirm,
      ),
      DarwinNotificationAction.plain(
        NotificationAction.later.id,
        _l10n.notificationActionLater,
      ),
      DarwinNotificationAction.plain(
        NotificationAction.talk.id,
        _l10n.notificationActionTalk(AppBrand.id),
        options: {DarwinNotificationActionOption.foreground},
      ),
    ],
  );

  @override
  Future<void> initialize({
    required void Function(String? payload, String? actionId) onTap,
    BackgroundAction? onBackgroundAction,
  }) async {
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Nothing is asked for here. The prompt waits for the moment the
        // user does something a reminder would be for.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [_askCategory],
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          onTap(response.payload, response.actionId),
      onDidReceiveBackgroundNotificationResponse: onBackgroundAction,
    );

    await _android?.createNotificationChannel(_blocksChannel);
    await _android?.createNotificationChannel(_dailyChannel);
  }

  @override
  Future<({String? payload, String? actionId})?> launchResponse() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;

    final response = details.notificationResponse;
    return (payload: response?.payload, actionId: response?.actionId);
  }

  @override
  Future<bool> isPermitted() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final options = await _ios?.checkPermissions();
      return options?.isEnabled ?? false;
    }

    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Critical alerts are not asked for: that entitlement is paid.
      return await _ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<Set<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return {for (final request in pending) request.id};
  }

  @override
  Future<void> schedule(QueuedNotification notification) async {
    final channel = notification.daily ? _dailyChannel : _blocksChannel;
    final exact = await _android?.canScheduleExactNotifications() ?? false;

    await _plugin.zonedSchedule(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      scheduledDate: notification.fireAt,
      payload: notification.payload,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: notification.daily
              ? Priority.defaultPriority
              : Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          // Shown while the app is open too: the app is not the only place
          // the user is looking.
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          interruptionLevel: notification.timeSensitive
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
          categoryIdentifier: notification.asks ? askCategory : null,
        ),
      ),
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
