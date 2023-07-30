import 'dart:math';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:moxlib/moxlib.dart';
import 'package:moxplatform/moxplatform.dart';
import 'package:moxplatform_platform_interface/moxplatform_platform_interface.dart';
import 'package:moxxyv2/i18n/strings.g.dart';
import 'package:moxxyv2/service/contacts.dart';
import 'package:moxxyv2/service/conversation.dart';
import 'package:moxxyv2/service/database/constants.dart';
import 'package:moxxyv2/service/database/database.dart';
import 'package:moxxyv2/service/message.dart';
import 'package:moxxyv2/service/service.dart';
import 'package:moxxyv2/service/xmpp.dart';
import 'package:moxxyv2/shared/error_types.dart';
import 'package:moxxyv2/shared/events.dart';
import 'package:moxxyv2/shared/helpers.dart';
import 'package:moxxyv2/shared/models/conversation.dart' as modelc;
import 'package:moxxyv2/shared/models/message.dart' as modelm;
import 'package:moxxyv2/shared/models/notification.dart' as modeln;

const _maxNotificationId = 2147483647;
const _messageChannelKey = 'message_channel';
const _warningChannelKey = 'warning_channel';

/// Message payload keys.
const _conversationJidKey = 'conversationJid';
const _messageIdKey = 'mid';
const _conversationTitleKey = 'title';
const _conversationAvatarKey = 'avatarPath';

class NotificationsService {
  NotificationsService() : _log = Logger('NotificationsService');
  // ignore: unused_field
  final Logger _log;

  Future<void> onNotificationEvent(NotificationEvent event) async {
    if (event.type == NotificationEventType.open) {
      // The notification has been tapped
      sendEvent(
        MessageNotificationTappedEvent(
          conversationJid: event.extra![_conversationJidKey]!,
          title: event.extra![_conversationTitleKey]!,
          avatarPath: event.extra![_conversationAvatarKey]!,
        ),
      );
    } else if (event.type == NotificationEventType.markAsRead) {
      // Mark the message as read
      await GetIt.I.get<MessageService>().markMessageAsRead(
            int.parse(event.extra![_messageIdKey]!),
            // [XmppService.sendReadMarker] will check whether the *SHOULD* send
            // the marker, i.e. if the privacy settings allow it.
            true,
          );

      // Update the conversation
      await GetIt.I.get<ConversationService>().createOrUpdateConversation(
        event.extra![_conversationJidKey]!,
        update: (conversation) async {
          final newConversation = conversation.copyWith(
            unreadCounter: 0,
          );

          // Notify the UI
          sendEvent(
            ConversationUpdatedEvent(
              conversation: newConversation,
            ),
          );

          return newConversation;
        },
      );

      // Clear notifications
      await dismissNotificationsByJid(event.extra![_conversationJidKey]!);
    } else if (event.type == NotificationEventType.reply) {
      // TODO: Handle
    }
  }

  Future<void> initialize() async {
    await MoxplatformPlugin.notifications.createNotificationChannel(
      t.notifications.channels.messagesChannelName,
      t.notifications.channels.messagesChannelDescription,
      _messageChannelKey,
      true,
    );
    await MoxplatformPlugin.notifications.createNotificationChannel(
      t.notifications.channels.warningChannelName,
      t.notifications.channels.warningChannelDescription,
      _warningChannelKey,
      false,
    );
    await MoxplatformPlugin.notifications.setI18n(
      NotificationI18nData(
        reply: t.notifications.message.reply,
        markAsRead: t.notifications.message.markAsRead,
        you: t.messages.you,
      ),
    );

    // Listen to notification events
    MoxplatformPlugin.notifications
        .getEventStream()
        .listen(onNotificationEvent);
  }

  /// Returns true if a notification should be shown. false otherwise.
  bool shouldShowNotification(String jid) {
    return GetIt.I.get<XmppService>().getCurrentlyOpenedChatJid() != jid;
  }

  /// Queries the notifications for the conversation [jid] from the database.
  Future<List<modeln.Notification>> _getNotificationsForJid(String jid) async {
    final rawNotifications =
        await GetIt.I.get<DatabaseService>().database.query(
      notificationsTable,
      where: 'conversationJid = ?',
      whereArgs: [jid],
    );
    return rawNotifications.map(modeln.Notification.fromJson).toList();
  }

  Future<int?> _clearNotificationsForJid(String jid) async {
    final db = GetIt.I.get<DatabaseService>().database;

    final result = await db.query(
      notificationsTable,
      where: 'conversationJid = ?',
      whereArgs: [jid],
      limit: 1,
    );

    // Assumption that all rows with the same conversationJid have the same id.
    final id = result.isNotEmpty ? result.first['id']! as int : null;
    await db.delete(
      notificationsTable,
      where: 'conversationJid = ?',
      whereArgs: [jid],
    );

    return id;
  }

  /// Show a notification for a message [m] grouped by its conversationJid
  /// attribute. If the message is a media message, i.e. mediaUrl != null and isMedia == true,
  /// then Android's BigPicture will be used.
  Future<void> showNotification(
    modelc.Conversation c,
    modelm.Message m,
    String title, {
    String? body,
  }) async {
    // See https://github.com/MaikuB/flutter_local_notifications/blob/master/flutter_local_notifications/example/lib/main.dart#L1293
    String body;
    if (m.stickerPackId != null) {
      body = t.messages.sticker;
    } else if (m.isMedia) {
      body = mimeTypeToEmoji(m.fileMetadata!.mimeType);
    } else {
      body = m.body;
    }

    final css = GetIt.I.get<ContactsService>();
    final contactIntegrationEnabled = await css.isContactIntegrationEnabled();
    final title =
        contactIntegrationEnabled ? c.contactDisplayName ?? c.title : c.title;
    final avatarPath = contactIntegrationEnabled
        ? c.contactAvatarPath ?? c.avatarPath
        : c.avatarPath;

    assert(
      implies(m.fileMetadata?.path != null, m.fileMetadata?.mimeType != null),
      'File metadata has path but no mime type',
    );

    final notifications = await _getNotificationsForJid(c.jid);
    final id = notifications.isNotEmpty
        ? notifications.first.id
        : Random().nextInt(_maxNotificationId);

    // Add to the database
    final newNotification = modeln.Notification(
      id,
      c.jid,
      title,
      m.senderJid.toString(),
      avatarPath.isEmpty ? null : avatarPath,
      body,
      m.fileMetadata?.mimeType,
      m.fileMetadata?.path,
      m.timestamp,
    );
    await GetIt.I.get<DatabaseService>().database.insert(
          notificationsTable,
          newNotification.toJson(),
        );
    final newMessage = newNotification.toNotificationMessage();
    _log.finest('Created notification with avatar "${newMessage.avatarPath}"');

    final payload = MessagingNotification(
      title: title,
      id: id,
      channelId: _messageChannelKey,
      jid: c.jid,
      messages: [
        ...notifications.map((n) => n.toNotificationMessage()),
        newMessage,
      ],
      // TODO
      isGroupchat: false,
      extra: {
        _conversationJidKey: c.jid,
        _messageIdKey: m.id.toString(),
        _conversationTitleKey: title,
        _conversationAvatarKey: avatarPath,
      },
    );
    _log.finest('Payload avatar: ${payload.messages.last!.avatarPath}');
    await MoxplatformPlugin.notifications.showMessagingNotification(
      payload,
    );
  }

  /// Show a notification with the highest priority that uses [title] as the title
  /// and [body] as the body.
  Future<void> showWarningNotification(String title, String body) async {
    await MoxplatformPlugin.notifications.showNotification(
      RegularNotification(
        title: title,
        body: body,
        channelId: _warningChannelKey,
        id: Random().nextInt(_maxNotificationId),
        icon: NotificationIcon.warning,
      ),
    );
  }

  /// Show a notification for a bounced message with erorr [type] for a
  /// message in the chat with [jid].
  Future<void> showMessageErrorNotification(
    String jid,
    MessageErrorType type,
  ) async {
    // Only show the notification for certain errors
    if (![
      MessageErrorType.remoteServerTimeout,
      MessageErrorType.remoteServerNotFound,
      MessageErrorType.serviceUnavailable
    ].contains(type)) {
      return;
    }

    final conversation =
        await GetIt.I.get<ConversationService>().getConversationByJid(jid);
    await MoxplatformPlugin.notifications.showNotification(
      RegularNotification(
        title: t.notifications.errors.messageError.title,
        body: t.notifications.errors.messageError
            .body(conversationTitle: conversation!.title),
        channelId: _warningChannelKey,
        id: Random().nextInt(_maxNotificationId),
        icon: NotificationIcon.error,
      ),
    );
  }

  /// Since all notifications are grouped by the conversation's JID, this function
  /// clears all notifications for [jid].
  Future<void> dismissNotificationsByJid(String jid) async {
    final id = await _clearNotificationsForJid(jid);
    if (id != null) {
      await MoxplatformPlugin.notifications.dismissNotification(id);
    }
  }
}
