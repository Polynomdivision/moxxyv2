import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:moxxmpp/moxxmpp.dart';
import 'package:moxxyv2/i18n/strings.g.dart';
import 'package:moxxyv2/service/avatars.dart';
import 'package:moxxyv2/service/blocking.dart';
import 'package:moxxyv2/service/contacts.dart';
import 'package:moxxyv2/service/conversation.dart';
import 'package:moxxyv2/service/database/constants.dart';
import 'package:moxxyv2/service/database/database.dart';
import 'package:moxxyv2/service/groupchat.dart';
import 'package:moxxyv2/service/helpers.dart';
import 'package:moxxyv2/service/httpfiletransfer/helpers.dart';
import 'package:moxxyv2/service/httpfiletransfer/httpfiletransfer.dart';
import 'package:moxxyv2/service/httpfiletransfer/jobs.dart';
import 'package:moxxyv2/service/httpfiletransfer/location.dart';
import 'package:moxxyv2/service/language.dart';
import 'package:moxxyv2/service/lifecycle.dart';
import 'package:moxxyv2/service/message.dart';
import 'package:moxxyv2/service/notifications.dart';
import 'package:moxxyv2/service/omemo/omemo.dart';
import 'package:moxxyv2/service/permissions.dart';
import 'package:moxxyv2/service/preferences.dart';
import 'package:moxxyv2/service/reactions.dart';
import 'package:moxxyv2/service/roster.dart';
import 'package:moxxyv2/service/service.dart';
import 'package:moxxyv2/service/stickers.dart';
import 'package:moxxyv2/service/storage.dart';
import 'package:moxxyv2/service/xmpp.dart';
import 'package:moxxyv2/service/xmpp_state.dart';
import 'package:moxxyv2/shared/commands.dart';
import 'package:moxxyv2/shared/debug.dart' as debug;
import 'package:moxxyv2/shared/error_types.dart';
import 'package:moxxyv2/shared/eventhandler.dart';
import 'package:moxxyv2/shared/events.dart';
import 'package:moxxyv2/shared/helpers.dart';
import 'package:moxxyv2/shared/models/conversation.dart';
import 'package:moxxyv2/shared/models/file_metadata.dart';
import 'package:moxxyv2/shared/models/groupchat.dart';
import 'package:moxxyv2/shared/models/preferences.dart';
import 'package:moxxyv2/shared/models/reaction_group.dart';
import 'package:moxxyv2/shared/models/sticker.dart' as sticker;
import 'package:moxxyv2/shared/models/sticker_pack.dart' as sticker_pack;
import 'package:moxxyv2/shared/models/xmpp_state.dart';
import 'package:moxxyv2/shared/synchronized_queue.dart';
import 'package:moxxyv2/ui/state/sendfiles.dart';

void setupBackgroundEventHandler() {
  final handler = EventHandler()
    ..addMatchers([
      EventTypeMatcher<LoginCommand>(performLogin),
      EventTypeMatcher<PerformPreStartCommand>(performPreStart),
      EventTypeMatcher<AddConversationCommand>(performAddConversation),
      EventTypeMatcher<AddContactCommand>(performAddContact),
      EventTypeMatcher<RemoveContactCommand>(performRemoveContact),
      EventTypeMatcher<SetOpenConversationCommand>(performSetOpenConversation),
      EventTypeMatcher<SendMessageCommand>(performSendMessage),
      EventTypeMatcher<BlockJidCommand>(performBlockJid),
      EventTypeMatcher<UnblockJidCommand>(performUnblockJid),
      EventTypeMatcher<UnblockAllCommand>(performUnblockAll),
      EventTypeMatcher<SetCSIStateCommand>(performSetCSIState),
      EventTypeMatcher<SetPreferencesCommand>(performSetPreferences),
      EventTypeMatcher<RequestDownloadCommand>(performRequestDownload),
      EventTypeMatcher<SetAvatarCommand>(performSetAvatar),
      EventTypeMatcher<SetShareOnlineStatusCommand>(
        performSetShareOnlineStatus,
      ),
      EventTypeMatcher<CloseConversationCommand>(performCloseConversation),
      EventTypeMatcher<SendChatStateCommand>(performSendChatState),
      EventTypeMatcher<GetFeaturesCommand>(performGetFeatures),
      EventTypeMatcher<SignOutCommand>(performSignOut),
      EventTypeMatcher<SendFilesCommand>(performSendFiles),
      EventTypeMatcher<SetConversationMuteStatusCommand>(performSetMuteState),
      EventTypeMatcher<GetConversationOmemoFingerprintsCommand>(
        performGetOmemoFingerprints,
      ),
      EventTypeMatcher<SetOmemoDeviceEnabledCommand>(performEnableOmemoKey),
      EventTypeMatcher<RecreateSessionsCommand>(performRecreateSessions),
      EventTypeMatcher<SetOmemoEnabledCommand>(performSetOmemoEnabled),
      EventTypeMatcher<GetOwnOmemoFingerprintsCommand>(
        performGetOwnOmemoFingerprints,
      ),
      EventTypeMatcher<RemoveOwnDeviceCommand>(performRemoveOwnDevice),
      EventTypeMatcher<RegenerateOwnDeviceCommand>(performRegenerateOwnDevice),
      EventTypeMatcher<RetractMessageCommentCommand>(performMessageRetraction),
      EventTypeMatcher<MarkConversationAsReadCommand>(
        performMarkConversationAsRead,
      ),
      EventTypeMatcher<MarkMessageAsReadCommand>(performMarkMessageAsRead),
      EventTypeMatcher<AddReactionToMessageCommand>(performAddMessageReaction),
      EventTypeMatcher<RemoveReactionFromMessageCommand>(
        performRemoveMessageReaction,
      ),
      EventTypeMatcher<MarkOmemoDeviceAsVerifiedCommand>(
        performMarkDeviceVerified,
      ),
      EventTypeMatcher<ImportStickerPackCommand>(performImportStickerPack),
      EventTypeMatcher<SendStickerCommand>(performSendSticker),
      EventTypeMatcher<RemoveStickerPackCommand>(performRemoveStickerPack),
      EventTypeMatcher<FetchStickerPackCommand>(performFetchStickerPack),
      EventTypeMatcher<InstallStickerPackCommand>(performStickerPackInstall),
      EventTypeMatcher<GetBlocklistCommand>(performGetBlocklist),
      EventTypeMatcher<GetPagedMessagesCommand>(performGetPagedMessages),
      EventTypeMatcher<GetPagedSharedMediaCommand>(performGetPagedSharedMedia),
      EventTypeMatcher<GetReactionsForMessageCommand>(performGetReactions),
      EventTypeMatcher<RequestAvatarForJidCommand>(performRequestAvatarForJid),
      EventTypeMatcher<JoinGroupchatCommand>(performJoinGroupchat),
      EventTypeMatcher<GetStorageUsageCommand>(performGetStorageUsage),
      EventTypeMatcher<DeleteOldMediaFilesCommand>(performOldMediaFileDeletion),
      EventTypeMatcher<GetPagedStickerPackCommand>(performGetPagedStickerPacks),
      EventTypeMatcher<GetStickerPackByIdCommand>(performGetStickerPackById),
      EventTypeMatcher<DebugCommand>(performDebugCommand),
      EventTypeMatcher<FetchRecipientInformationCommand>(
        performFetchRecipientInformation,
      ),
      EventTypeMatcher<ExitConversationCommand>(performConversationExited),
      EventTypeMatcher<GetMembersForGroupchatCommand>(performGetMembers),
      EventTypeMatcher<PerformConversationSearch>(performConversationSearch),
      EventTypeMatcher<ConversationSetFavourite>(
        performSetConversationFavourite,
      ),
    ]);

  GetIt.I.registerSingleton<EventHandler>(handler);
  GetIt.I.registerSingleton<SynchronizedQueue<Map<String, dynamic>?>>(
    SynchronizedQueue<Map<String, dynamic>?>(handleUIEvent),
  );
}

Future<void> performLogin(LoginCommand command, {dynamic extra}) async {
  final id = extra as String;

  // Set up the XMPP state
  final xss = GetIt.I.get<XmppStateService>();
  await xss.setAccountJid(command.jid, commit: false);
  await xss.modifyXmppState(
    (state) => state.copyWith(
      jid: command.jid,
      password: command.password,
    ),
    commit: false,
  );

  GetIt.I.get<Logger>().fine('Performing login...');
  final result = await GetIt.I.get<XmppService>().connectAwaitable(
        ConnectionSettings(
          jid: JID.fromString(command.jid),
          password: command.password,
        ),
        true,
      );
  GetIt.I.get<Logger>().fine('Login done');

  // ignore: avoid_dynamic_calls
  final xc = GetIt.I.get<XmppConnection>();
  if (result.isType<bool>() && result.get<bool>()) {
    // Persistently store the JID
    await xss.setAccountJid(command.jid);

    // Commit the XMPP state
    await xss.commitXmppState(command.jid);

    final preferences =
        await GetIt.I.get<PreferencesService>().getPreferences();
    final settings = xc.connectionSettings;
    final state = await xss.state;

    sendEvent(
      LoginSuccessfulEvent(
        jid: settings.jid.toString(),
        preStart: await _buildPreStartDoneEvent(
          state,
          command.jid,
          preferences,
        ),
      ),
      id: id,
    );
  } else {
    await GetIt.I.get<XmppStateService>().resetAccountJid();
    await xc.reconnectionPolicy.setShouldReconnect(false);
    sendEvent(
      LoginFailureEvent(
        reason: xmppErrorToTranslatableString(result.get<XmppError>()),
      ),
      id: id,
    );
  }
}

Future<PreStartDoneEvent> _buildPreStartDoneEvent(
  XmppState state,
  String accountJid,
  PreferencesState preferences,
) async {
  await GetIt.I.get<RosterService>().loadRosterFromDatabase(accountJid);

  return PreStartDoneEvent(
    state: 'logged_in',
    jid: accountJid,
    displayName: state.displayName ?? accountJid.split('@').first,
    avatarUrl: state.avatarUrl,
    avatarHash: state.avatarHash,
    preferences: preferences,
    requestNotificationPermission: await GetIt.I
        .get<PermissionsService>()
        .shouldRequestNotificationPermission(),
    excludeFromBatteryOptimisation: await GetIt.I
        .get<PermissionsService>()
        .shouldRequestBatteryOptimisationExcemption(),
    conversations:
        (await GetIt.I.get<ConversationService>().loadConversations(accountJid))
            .where((c) => c.open)
            .toList(),
    roster:
        await GetIt.I.get<RosterService>().loadRosterFromDatabase(accountJid),
  );
}

Future<void> performPreStart(
  PerformPreStartCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;
  final preferences = await GetIt.I.get<PreferencesService>().getPreferences();

  // Set the locale very early
  final logger = GetIt.I.get<Logger>();
  GetIt.I.get<LanguageService>().defaultLocale = command.systemLocaleCode;
  if (preferences.languageLocaleCode == 'default') {
    LocaleSettings.setLocaleRaw(command.systemLocaleCode);
    logger.finest('Setting locale to default (${command.systemLocaleCode})');
  } else {
    LocaleSettings.setLocaleRaw(preferences.languageLocaleCode);
    logger.finest(
      'Setting locale to configured language (${preferences.languageLocaleCode})',
    );
  }
  await GetIt.I.get<NotificationsService>().configureNotificationI18n();
  GetIt.I.get<XmppService>().setNotificationText(
        await GetIt.I.get<XmppConnection>().getConnectionState(),
      );

  // Check if we have an account JID and, if we do, if we have login data.
  final xss = GetIt.I.get<XmppStateService>();
  final accountJid = await xss.getAccountJid();
  if (await xss.isLoggedIn(accountJid)) {
    sendEvent(
      await _buildPreStartDoneEvent(
        await xss.state,
        accountJid!,
        preferences,
      ),
      id: id,
    );
  } else {
    sendEvent(
      PreStartDoneEvent(
        state: 'not_logged_in',
        requestNotificationPermission: false,
        excludeFromBatteryOptimisation: false,
        preferences: preferences,
      ),
      id: id,
    );
  }
}

Future<void> performAddConversation(
  AddConversationCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;

  final cs = GetIt.I.get<ConversationService>();
  final css = GetIt.I.get<ContactsService>();
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final preferences = await GetIt.I.get<PreferencesService>().getPreferences();
  final conversation = await cs.createOrUpdateConversation(
    command.jid,
    accountJid!,
    create: () async {
      // Create
      final contactId = await css.getContactIdForJid(command.jid);
      final newConversation = await cs.addConversationFromData(
        accountJid,
        command.title,
        null,
        ConversationType.fromString(command.conversationType),
        command.avatarUrl,
        command.jid,
        0,
        DateTime.now().millisecondsSinceEpoch,
        true,
        preferences.defaultMuteState,
        preferences.enableOmemoByDefault,
        contactId,
        await css.getProfilePicturePathForJid(command.jid),
        await css.getContactDisplayName(contactId),
        null,
      );

      sendEvent(
        ConversationAddedEvent(
          conversation: newConversation,
        ),
        id: id,
      );
      return newConversation;
    },
    update: (c) async {
      // Update
      if (!c.open) {
        // Re-open the conversation
        final newConversation = await cs.updateConversation(
          c.jid,
          accountJid,
          open: true,
          lastChangeTimestamp: DateTime.now().millisecondsSinceEpoch,
        );

        sendEvent(
          ConversationAddedEvent(
            conversation: newConversation,
          ),
          id: id,
        );
        return newConversation;
      }

      sendEvent(
        NoConversationModifiedEvent(),
        id: id,
      );
      return c;
    },
  );

  if (conversation!.type == ConversationType.groupchat) {
    await GetIt.I.get<GroupchatService>().joinRoom(
          JID.fromString(conversation.jid),
          accountJid,
          conversation.groupchatDetails!.nick,
        );
  }
}

Future<void> performSetOpenConversation(
  SetOpenConversationCommand command, {
  dynamic extra,
}) async {
  await GetIt.I.get<XmppService>().setCurrentlyOpenedChatJid(command.jid ?? '');

  // Null just means that the chat has been closed
  // Empty string JID for notes to self
  if (command.jid != null && command.jid != '') {
    await GetIt.I.get<NotificationsService>().dismissNotificationsByJid(
          command.jid!,
          (await GetIt.I.get<XmppStateService>().getAccountJid())!,
        );
  }
}

Future<void> performSendMessage(
  SendMessageCommand command, {
  dynamic extra,
}) async {
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final xs = GetIt.I.get<XmppService>();
  if (command.editSid != null) {
    assert(
      command.recipients.length == 1,
      'Edits must not be sent to multiple recipients',
    );

    await xs.sendMessageCorrection(
      command.editSid!,
      command.recipients.first,
      accountJid!,
      command.body,
      command.editSid!,
      command.recipients.first,
      command.chatState.isNotEmpty
          ? ChatState.fromName(command.chatState)
          : null,
    );
    return;
  }

  await xs.sendMessage(
    accountJid: accountJid!,
    body: command.body,
    recipients: command.recipients,
    chatState: command.chatState.isNotEmpty
        ? ChatState.fromName(command.chatState)
        : null,
    quotedMessage: command.quotedMessage,
    currentConversationJid: command.currentConversationJid,
    commandId: extra as String,
  );
}

Future<void> performBlockJid(BlockJidCommand command, {dynamic extra}) async {
  final result = await GetIt.I.get<BlocklistService>().blockJid(command.jid);
  if (result) {
    return;
  }

  // Notify the user of the failure
  await GetIt.I.get<NotificationsService>().showWarningNotification(
        t.notifications.warnings.blockingError.title,
        t.notifications.warnings.blockingError.body(jid: command.jid),
      );
}

Future<void> performUnblockJid(
  UnblockJidCommand command, {
  dynamic extra,
}) async {
  await GetIt.I.get<BlocklistService>().unblockJid(command.jid);
}

Future<void> performUnblockAll(
  UnblockAllCommand command, {
  dynamic extra,
}) async {
  await GetIt.I.get<BlocklistService>().unblockAll();
}

Future<void> performSetCSIState(
  SetCSIStateCommand command, {
  dynamic extra,
}) async {
  // Tell the [XmppService] about the app state
  GetIt.I.get<LifecycleService>().isActive = command.active;

  // Only send the CSI nonza when we're connected
  final conn = GetIt.I.get<XmppConnection>();
  if (await conn.getConnectionState() != XmppConnectionState.connected) return;
  final csi = conn.getManagerById<CSIManager>(csiManager)!;
  if (command.active) {
    await csi.setActive();
  } else {
    await csi.setInactive();
  }
}

Future<void> performSetPreferences(
  SetPreferencesCommand command, {
  dynamic extra,
}) async {
  final ps = GetIt.I.get<PreferencesService>();
  final oldPrefs = await ps.getPreferences();
  await ps.modifyPreferences((_) => command.preferences);

  // Set the logging mode
  if (!kDebugMode) {
    final enableDebug = command.preferences.debugEnabled;
    Logger.root.level = enableDebug ? Level.ALL : Level.INFO;
  }

  // Scan all contacts if the setting is enabled or disable the database callback
  // if it is disabled.
  final css = GetIt.I.get<ContactsService>();
  if (command.preferences.enableContactIntegration) {
    if (!oldPrefs.enableContactIntegration) {
      await css.enable();
    }

    unawaited(css.scanContacts());
  } else {
    if (oldPrefs.enableContactIntegration) {
      await css.disable();
    }
  }

  // TODO(Unknown): Maybe handle this in StickersService
  // If sticker visibility was changed, apply the settings to the PubSub node
  final xss = GetIt.I.get<XmppStateService>();
  final pm = GetIt.I
      .get<XmppConnection>()
      .getManagerById<PubSubManager>(pubsubManager)!;
  final ownJid = JID.fromString(
    (await xss.state).jid!,
  );
  if (command.preferences.isStickersNodePublic &&
      !oldPrefs.isStickersNodePublic) {
    // Set to open
    unawaited(
      pm.configure(
        ownJid,
        stickersXmlns,
        const PubSubPublishOptions(
          accessModel: 'open',
          maxItems: 'max',
        ),
      ),
    );
  } else if (!command.preferences.isStickersNodePublic &&
      oldPrefs.isStickersNodePublic) {
    // Set to presence
    unawaited(
      pm.configure(
        ownJid,
        stickersXmlns,
        const PubSubPublishOptions(
          accessModel: 'presence',
          maxItems: 'max',
        ),
      ),
    );
  }

  // Set the locale
  final locale = command.preferences.languageLocaleCode == 'default'
      ? GetIt.I.get<LanguageService>().defaultLocale
      : command.preferences.languageLocaleCode;
  LocaleSettings.setLocaleRaw(locale);
  GetIt.I.get<XmppService>().setNotificationText(
        await GetIt.I.get<XmppConnection>().getConnectionState(),
      );
  await GetIt.I.get<NotificationsService>().configureNotificationI18n();
}

/// Attempts to achieve a "both" subscription with [jid].
Future<void> _maybeAchieveBothSubscription(
  String jid,
  String accountJid,
) async {
  final roster = GetIt.I.get<RosterService>();
  final item = await roster.getRosterItemByJid(jid, accountJid);
  if (item != null) {
    GetIt.I.get<Logger>().finest(
          'Roster item for $jid has subscription "${item.subscription}" with ask "${item.ask}"',
        );

    // Nothing more to do
    if (item.subscription == 'both') {
      return;
    }

    final pm = GetIt.I
        .get<XmppConnection>()
        .getManagerById<PresenceManager>(presenceManager)!;
    switch (item.subscription) {
      case 'both':
        return;
      case 'none':
      case 'from':
        if (item.ask != 'subscribe') {
          // Try to move from "from"/"none" to "both", by going over "From + Pending Out"
          await pm.requestSubscription(JID.fromString(item.jid));
        }
      case 'to':
        // Move from "to" to "both"
        await pm.acceptSubscriptionRequest(JID.fromString(item.jid));
    }
  } else {
    await roster.addToRosterWrapper(
      accountJid,
      null,
      null,
      jid,
      jid.split('@')[0],
    );
  }
}

Future<void> performAddContact(
  AddContactCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;
  final jid = command.jid;
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final roster = GetIt.I.get<RosterService>();
  final inRoster = await roster.isInRoster(jid, accountJid!);
  final cs = GetIt.I.get<ConversationService>();

  final conversation = await cs.getConversationByJid(jid, accountJid);
  if (conversation != null) {
    await cs.createOrUpdateConversation(
      jid,
      accountJid,
      update: (c) async {
        final newConversation = await cs.updateConversation(
          jid,
          accountJid,
          open: true,
          lastChangeTimestamp: DateTime.now().millisecondsSinceEpoch,
        );

        sendEvent(
          AddContactResultEvent(
            conversation: newConversation,
            added: !inRoster,
          ),
          id: id,
        );

        return newConversation;
      },
    );

    switch (conversation.type) {
      case ConversationType.chat:
        // Add to roster, if needed
        await _maybeAchieveBothSubscription(jid, accountJid);
      case ConversationType.groupchat:
        // The conversation was closed (we left the groupchat), so join it again.
        await GetIt.I.get<GroupchatService>().joinRoom(
              JID.fromString(conversation.jid),
              accountJid,
              conversation.groupchatDetails!.nick,
            );
      case ConversationType.note:
        break;
    }
  } else {
    // We did not have a conversation with that JID.
    final info = await GetIt.I
        .get<XmppConnection>()
        .getDiscoManager()!
        .discoInfoQuery(JID.fromString(jid));
    var isGroupchat = false;
    if (info.isType<DiscoInfo>()) {
      isGroupchat = info.get<DiscoInfo>().identities.firstWhereOrNull(
                (identity) => identity.category == 'conference',
              ) !=
          null;
    } else if (info.isType<RemoteServerNotFoundError>()) {
      sendEvent(
        ErrorEvent(
          errorId: ErrorType.remoteServerNotFound.value,
        ),
        id: id,
      );
      return;
    } else if (info.isType<RemoteServerTimeoutError>()) {
      sendEvent(
        ErrorEvent(
          errorId: ErrorType.remoteServerTimeout.value,
        ),
        id: id,
      );
      return;
    }

    if (isGroupchat) {
      // The JID points to a groupchat. Handle that on the UI side
      sendEvent(
        JidIsGroupchatEvent(jid: jid),
        id: id,
      );
    } else {
      await cs.createOrUpdateConversation(
        jid,
        accountJid,
        create: () async {
          // Create
          final css = GetIt.I.get<ContactsService>();
          final contactId = await css.getContactIdForJid(jid);
          final prefs =
              await GetIt.I.get<PreferencesService>().getPreferences();
          final newConversation = await cs.addConversationFromData(
            accountJid,
            jid.split('@')[0],
            null,
            ConversationType.chat,
            null,
            jid,
            0,
            DateTime.now().millisecondsSinceEpoch,
            true,
            prefs.defaultMuteState,
            prefs.enableOmemoByDefault,
            contactId,
            await css.getProfilePicturePathForJid(jid),
            await css.getContactDisplayName(contactId),
            null,
          );

          sendEvent(
            AddContactResultEvent(
              conversation: newConversation,
              added: !inRoster,
            ),
            id: id,
          );

          return newConversation;
        },
      );

      // Add to roster, if required
      await _maybeAchieveBothSubscription(jid, accountJid);
    }
  }
}

Future<void> performRemoveContact(
  RemoveContactCommand command, {
  dynamic extra,
}) async {
  final rs = GetIt.I.get<RosterService>();
  final cs = GetIt.I.get<ConversationService>();
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();

  // Remove from roster
  await rs.removeFromRosterWrapper(command.jid, accountJid!);

  // Update the conversation
  final conversation = await cs.getConversationByJid(command.jid, accountJid);
  if (conversation != null) {
    sendEvent(
      ConversationUpdatedEvent(
        conversation: conversation.copyWith(
          showAddToRoster: true,
        ),
      ),
    );
  }
}

Future<void> performRequestDownload(
  RequestDownloadCommand command, {
  dynamic extra,
}) async {
  final ms = GetIt.I.get<MessageService>();
  final srv = GetIt.I.get<HttpFileTransferService>();
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();

  final message = await ms.updateMessage(
    command.message.id,
    accountJid!,
    isDownloading: true,
  );
  sendEvent(MessageUpdatedEvent(message: message));

  final fileMetadata = command.message.fileMetadata!;
  final metadata = await peekFile(fileMetadata.sourceUrls!.first);

  // TODO(Unknown): Maybe deduplicate with the code in the xmpp service
  // NOTE: This either works by returing "jpg" for ".../hallo.jpg" or fails
  //       for ".../aaaaaaaaa", in which case we would've failed anyways.
  final ext = fileMetadata.sourceUrls!.first.split('.').last;
  final mimeGuess = metadata.mime ?? guessMimeTypeFromExtension(ext);

  await srv.downloadFile(
    FileDownloadJob(
      message.id,
      message.conversationJid,
      accountJid,
      MediaFileLocation(
        fileMetadata.sourceUrls!,
        fileMetadata.filename,
        fileMetadata.encryptionScheme,
        fileMetadata.encryptionKey != null
            ? base64Decode(fileMetadata.encryptionKey!)
            : null,
        fileMetadata.encryptionIv != null
            ? base64Decode(fileMetadata.encryptionIv!)
            : null,
        fileMetadata.plaintextHashes,
        fileMetadata.ciphertextHashes,
        null,
      ),
      message.fileMetadata!.id,
      message.fileMetadata!.plaintextHashes?.isNotEmpty ?? false,
      mimeGuess,
    ),
  );
}

Future<void> performSetAvatar(SetAvatarCommand command, {dynamic extra}) async {
  // Publish our avatar
  await GetIt.I.get<AvatarService>().setNewAvatar(command.path, command.hash);
}

Future<void> performSetShareOnlineStatus(
  SetShareOnlineStatusCommand command, {
  dynamic extra,
}) async {
  final rs = GetIt.I.get<RosterService>();
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final item = await rs.getRosterItemByJid(command.jid, accountJid!);

  // TODO(Unknown): Maybe log
  if (item == null) return;

  final jid = JID.fromString(command.jid);
  final pm = GetIt.I
      .get<XmppConnection>()
      .getManagerById<PresenceManager>(presenceManager)!;
  if (command.share) {
    switch (item.subscription) {
      case 'to':
        await pm.acceptSubscriptionRequest(jid);
      case 'none':
      case 'from':
        await pm.requestSubscription(jid);
    }
  } else {
    switch (item.subscription) {
      case 'both':
      case 'from':
      case 'to':
        await pm.unsubscribe(jid);
    }
  }
}

Future<void> performCloseConversation(
  CloseConversationCommand command, {
  dynamic extra,
}) async {
  final cs = GetIt.I.get<ConversationService>();
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();

  Logger.root.finest('Attempting to close ${command.jid}');
  final conversation = await cs.createOrUpdateConversation(
    command.jid,
    accountJid!,
    update: (c) async {
      return cs.updateConversation(
        command.jid,
        accountJid,
        open: false,
      );
    },
  );

  assert(conversation != null, 'Conversation must be non-null');
  if (conversation?.type == ConversationType.groupchat) {
    await GetIt.I
        .get<XmppConnection>()
        .getManagerById<MUCManager>(mucManager)!
        .leaveRoom(JID.fromString(conversation!.jid));
  }

  sendEvent(
    CloseConversationEvent(),
    id: extra as String,
  );
}

Future<void> performSendChatState(
  SendChatStateCommand command, {
  dynamic extra,
}) async {
  await GetIt.I.get<ConversationService>().sendChatState(
        ConversationType.fromString(command.conversationType),
        command.jid,
        ChatState.fromName(command.state),
      );
}

Future<void> performGetFeatures(
  GetFeaturesCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;

  final conn = GetIt.I.get<XmppConnection>();
  final sm = conn.getNegotiatorById<StreamManagementNegotiator>(
    streamManagementNegotiator,
  )!;
  final csi = conn.getNegotiatorById<CSINegotiator>(csiNegotiator)!;
  final httpFileUpload =
      conn.getManagerById<HttpFileUploadManager>(httpFileUploadManager)!;
  final userBlocking = conn.getManagerById<BlockingManager>(blockingManager)!;
  final carbons = conn.getManagerById<CarbonsManager>(carbonsManager)!;
  sendEvent(
    GetFeaturesEvent(
      supportsStreamManagement: sm.isSupported,
      supportsCsi: csi.isSupported,
      supportsHttpFileUpload: await httpFileUpload.isSupported(),
      supportsUserBlocking: await userBlocking.isSupported(),
      supportsCarbons: await carbons.isSupported(),
    ),
    id: id,
  );
}

Future<void> performSignOut(SignOutCommand command, {dynamic extra}) async {
  final id = extra as String;

  final conn = GetIt.I.get<XmppConnection>();
  final xss = GetIt.I.get<XmppStateService>();
  unawaited(conn.disconnect());
  await xss.modifyXmppState(
    (state) => XmppState(),
  );

  // Clear notifications
  final accountJid = await xss.getAccountJid();
  await GetIt.I
      .get<NotificationsService>()
      .dismissAllNotifications(accountJid!);

  // Reset the current account JID.
  await xss.resetAccountJid();

  sendEvent(
    SignedOutEvent(),
    id: id,
  );
}

Future<void> performSendFiles(SendFilesCommand command, {dynamic extra}) async {
  await GetIt.I.get<XmppService>().sendFiles(
        (await GetIt.I.get<XmppStateService>().getAccountJid())!,
        command.paths,
        command.recipients,
      );
}

Future<void> performSetMuteState(
  SetConversationMuteStatusCommand command, {
  dynamic extra,
}) async {
  final cs = GetIt.I.get<ConversationService>();
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();

  final conversation = await cs.createOrUpdateConversation(
    command.jid,
    accountJid!,
    update: (c) async {
      return cs.updateConversation(
        command.jid,
        accountJid,
        muted: command.muted,
      );
    },
  );

  if (conversation != null) {
    sendEvent(ConversationUpdatedEvent(conversation: conversation));
  }
}

Future<void> performGetOmemoFingerprints(
  GetConversationOmemoFingerprintsCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;

  final omemo = GetIt.I.get<OmemoService>();
  sendEvent(
    GetConversationOmemoFingerprintsResult(
      fingerprints: await omemo.getFingerprintsForJid(command.jid),
    ),
    id: id,
  );
}

Future<void> performEnableOmemoKey(
  SetOmemoDeviceEnabledCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;

  final omemo = GetIt.I.get<OmemoService>();
  await omemo.setDeviceEnablement(
    command.jid,
    command.deviceId,
    command.enabled,
  );

  await performGetOmemoFingerprints(
    GetConversationOmemoFingerprintsCommand(jid: command.jid),
    extra: id,
  );
}

Future<void> performRecreateSessions(
  RecreateSessionsCommand command, {
  dynamic extra,
}) async {
  // NOTE: As [removeAllRatchets] delegates the deletion to the OmemoManager, this call
  //       is implicitly dependent on the account JID.
  // Remove all ratchets
  await GetIt.I.get<OmemoService>().removeAllRatchets(command.jid);

  // And force the creation of new ones
  await GetIt.I
      .get<XmppConnection>()
      .getManagerById<OmemoManager>(omemoManager)!
      .sendOmemoHeartbeat(
        command.jid,
      );
}

Future<void> performSetOmemoEnabled(
  SetOmemoEnabledCommand command, {
  dynamic extra,
}) async {
  final cs = GetIt.I.get<ConversationService>();
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();

  await cs.createOrUpdateConversation(
    command.jid,
    accountJid!,
    update: (c) async {
      return cs.updateConversation(
        command.jid,
        accountJid,
        encrypted: command.enabled,
      );
    },
  );
}

Future<void> performGetOwnOmemoFingerprints(
  GetOwnOmemoFingerprintsCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;
  final os = GetIt.I.get<OmemoService>();
  final xs = GetIt.I.get<XmppService>();

  final jid = (await xs.getConnectionSettings())!.jid;
  final device = await os.getDevice();
  sendEvent(
    GetOwnOmemoFingerprintsResult(
      ownDeviceFingerprint: await device.getFingerprint(),
      ownDeviceId: device.id,
      fingerprints: await os.getFingerprintsForJid(jid.toString()),
    ),
    id: id,
  );
}

Future<void> performRemoveOwnDevice(
  RemoveOwnDeviceCommand command, {
  dynamic extra,
}) async {
  await GetIt.I
      .get<XmppConnection>()
      .getManagerById<OmemoManager>(omemoManager)!
      .deleteDevice(command.deviceId);
}

Future<void> performRegenerateOwnDevice(
  RegenerateOwnDeviceCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;
  final device = await GetIt.I.get<OmemoService>().regenerateDevice();

  sendEvent(
    RegenerateOwnDeviceResult(device: device),
    id: id,
  );
}

Future<void> performMessageRetraction(
  RetractMessageCommentCommand command, {
  dynamic extra,
}) async {
  await GetIt.I.get<MessageService>().retractMessage(
        command.conversationJid,
        (await GetIt.I.get<XmppStateService>().getAccountJid())!,
        command.originId,
        '',
        true,
      );
  if (command.conversationJid != '') {
    final manager = GetIt.I
        .get<XmppConnection>()
        .getManagerById<MessageManager>(messageManager)!;
    await manager.sendMessage(
      JID.fromString(command.conversationJid),
      TypedMap<StanzaHandlerExtension>.fromList([
        MessageRetractionData(command.originId, t.messages.retractedFallback),
      ]),
    );
  }
}

Future<void> performMarkConversationAsRead(
  MarkConversationAsReadCommand command, {
  dynamic extra,
}) async {
  final cs = GetIt.I.get<ConversationService>();
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();

  // Update the database
  final conversation = await cs.createOrUpdateConversation(
    command.conversationJid,
    accountJid!,
    update: (c) async {
      return cs.updateConversation(
        command.conversationJid,
        accountJid,
        unreadCounter: 0,
      );
    },
  );
  if (conversation != null) {
    sendEvent(ConversationUpdatedEvent(conversation: conversation));

    if (conversation.lastMessage != null) {
      await GetIt.I.get<MessageService>().markMessageAsRead(
            conversation.lastMessage!.id,
            accountJid,
            conversation.type != ConversationType.note,
          );
    }
  }

  // Dismiss notifications for that chat
  await GetIt.I.get<NotificationsService>().dismissNotificationsByJid(
        command.conversationJid,
        (await GetIt.I.get<XmppStateService>().getAccountJid())!,
      );
}

Future<void> performMarkMessageAsRead(
  MarkMessageAsReadCommand command, {
  dynamic extra,
}) async {
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  await GetIt.I.get<MessageService>().markMessageAsRead(
        command.id,
        accountJid!,
        command.sendMarker,
      );
}

Future<void> performAddMessageReaction(
  AddReactionToMessageCommand command, {
  dynamic extra,
}) async {
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final rs = GetIt.I.get<ReactionsService>();
  final msg = await rs.addNewReaction(
    command.id,
    accountJid!,
    accountJid,
    command.emoji,
  );
  if (msg == null) {
    return;
  }

  // Notify the UI
  sendEvent(
    MessageUpdatedEvent(
      message: msg,
    ),
  );

  if (msg.conversationJid != '') {
    // Send the reaction
    final manager = GetIt.I
        .get<XmppConnection>()
        .getManagerById<MessageManager>(messageManager)!;
    await manager.sendMessage(
      JID.fromString(msg.conversationJid),
      TypedMap<StanzaHandlerExtension>.fromList([
        MessageReactionsData(
          msg.originId ?? msg.sid,
          await rs.getReactionsForMessageByJid(
            command.id,
            accountJid,
            accountJid,
          ),
        ),
        MessageProcessingHintData([
          if (!msg.containsNoStore) MessageProcessingHint.store,
        ]),
      ]),
    );
  }
}

Future<void> performRemoveMessageReaction(
  RemoveReactionFromMessageCommand command, {
  dynamic extra,
}) async {
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final rs = GetIt.I.get<ReactionsService>();
  final msg = await rs.removeReaction(
    command.id,
    accountJid!,
    accountJid,
    command.emoji,
  );
  if (msg == null) {
    return;
  }

  // Notify the UI
  sendEvent(
    MessageUpdatedEvent(
      message: msg,
    ),
  );

  if (msg.conversationJid != '') {
    // Send the reaction
    final manager = GetIt.I
        .get<XmppConnection>()
        .getManagerById<MessageManager>(messageManager)!;
    await manager.sendMessage(
      JID.fromString(msg.conversationJid),
      TypedMap<StanzaHandlerExtension>.fromList([
        MessageReactionsData(
          msg.originId ?? msg.sid,
          await rs.getReactionsForMessageByJid(
            command.id,
            accountJid,
            accountJid,
          ),
        ),
        MessageProcessingHintData([
          if (!msg.containsNoStore) MessageProcessingHint.store,
        ]),
      ]),
    );
  }
}

Future<void> performMarkDeviceVerified(
  MarkOmemoDeviceAsVerifiedCommand command, {
  dynamic extra,
}) async {
  await GetIt.I.get<OmemoService>().setDeviceVerified(
        command.jid,
        command.deviceId,
      );
}

Future<void> performImportStickerPack(
  ImportStickerPackCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;
  final result =
      await GetIt.I.get<StickersService>().importFromFile(command.path);
  if (result != null) {
    sendEvent(
      StickerPackImportSuccessEvent(
        stickerPack: result,
      ),
      id: id,
    );
  } else {
    sendEvent(
      StickerPackImportFailureEvent(),
      id: id,
    );
  }
}

Future<void> performSendSticker(
  SendStickerCommand command, {
  dynamic extra,
}) async {
  await GetIt.I.get<XmppService>().sendMessage(
        accountJid: (await GetIt.I.get<XmppStateService>().getAccountJid())!,
        body: command.sticker.desc,
        recipients: [command.recipient],
        sticker: command.sticker,
        currentConversationJid: command.recipient,
        quotedMessage: command.quotes,
      );
}

Future<void> performRemoveStickerPack(
  RemoveStickerPackCommand command, {
  dynamic extra,
}) async {
  await GetIt.I.get<StickersService>().removeStickerPack(
        command.stickerPackId,
      );
}

Future<void> performFetchStickerPack(
  FetchStickerPackCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;

  final result = await GetIt.I
      .get<XmppConnection>()
      .getManagerById<StickersManager>(stickersManager)!
      .fetchStickerPack(JID.fromString(command.jid), command.stickerPackId);

  if (result.isType<PubSubError>()) {
    sendEvent(
      FetchStickerPackFailureResult(),
      id: id,
    );
  } else {
    final stickerPack = result.get<StickerPack>();
    sendEvent(
      FetchStickerPackSuccessResult(
        stickerPack: sticker_pack.StickerPack(
          command.stickerPackId,
          stickerPack.name,
          stickerPack.summary,
          stickerPack.stickers
              .map(
                (s) => sticker.Sticker(
                  '',
                  command.stickerPackId,
                  s.metadata.desc!,
                  s.suggests,
                  FileMetadata(
                    '',
                    null,
                    s.sources
                        .whereType<StatelessFileSharingUrlSource>()
                        .map((src) => src.url)
                        .toList(),
                    s.metadata.mediaType,
                    s.metadata.size,
                    // TODO(Unknown): One day
                    null,
                    null,
                    s.metadata.width,
                    s.metadata.height,
                    s.metadata.hashes,
                    null,
                    null,
                    null,
                    null,
                    s.metadata.name ?? '',
                  ),
                ),
              )
              .toList(),
          stickerPack.hashAlgorithm.toName(),
          stickerPack.hashValue,
          stickerPack.restricted,
          false,
          0,
          0,
        ),
      ),
      id: id,
    );
  }
}

Future<void> performStickerPackInstall(
  InstallStickerPackCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;

  final ss = GetIt.I.get<StickersService>();
  final pack = await ss.installFromPubSub(command.stickerPack);
  if (pack != null) {
    sendEvent(
      StickerPackInstallSuccessEvent(
        stickerPack: pack,
      ),
      id: id,
    );
  } else {
    sendEvent(
      StickerPackInstallFailureEvent(),
      id: id,
    );
  }
}

Future<void> performGetBlocklist(
  GetBlocklistCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final result =
      await GetIt.I.get<BlocklistService>().getBlocklist(accountJid!);
  sendEvent(
    GetBlocklistResultEvent(
      entries: result,
    ),
    id: id,
  );
}

Future<void> performGetPagedMessages(
  GetPagedMessagesCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final result = await GetIt.I.get<MessageService>().getPaginatedMessagesForJid(
        command.conversationJid,
        accountJid!,
        command.olderThan,
        command.timestamp,
      );

  sendEvent(
    PagedMessagesResultEvent(
      messages: result,
    ),
    id: id,
  );
}

Future<void> performGetPagedSharedMedia(
  GetPagedSharedMediaCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;
  final result =
      await GetIt.I.get<MessageService>().getPaginatedSharedMediaMessagesForJid(
            command.conversationJid,
            (await GetIt.I.get<XmppStateService>().getAccountJid())!,
            command.olderThan,
            command.timestamp,
          );

  sendEvent(
    PagedMessagesResultEvent(
      messages: result,
    ),
    id: id,
  );
}

Future<void> performGetReactions(
  GetReactionsForMessageCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final reactionsRaw =
      await GetIt.I.get<ReactionsService>().getReactionsForMessage(
            command.id,
            accountJid!,
          );
  final reactionsMap = <String, List<String>>{};
  for (final reaction in reactionsRaw) {
    if (reactionsMap.containsKey(reaction.senderJid)) {
      reactionsMap[reaction.senderJid]!.add(reaction.emoji);
    } else {
      reactionsMap[reaction.senderJid] = List<String>.from([reaction.emoji]);
    }
  }

  sendEvent(
    ReactionsForMessageResult(
      reactions: reactionsMap.entries
          .map(
            (entry) => ReactionGroup(
              entry.key,
              entry.value,
            ),
          )
          .toList(),
    ),
    id: id,
  );
}

Future<void> performRequestAvatarForJid(
  RequestAvatarForJidCommand command, {
  dynamic extra,
}) async {
  final as = GetIt.I.get<AvatarService>();
  Future<void> future;
  if (command.ownAvatar) {
    future = as.requestOwnAvatar();
  } else {
    future = command.isGroupchat
        ? as.requestGroupchatAvatar(
            JID.fromString(command.jid),
            command.hash,
          )
        : as.requestAvatar(
            JID.fromString(command.jid),
            command.hash,
          );
  }

  unawaited(future);
}

Future<void> performGetStorageUsage(
  GetStorageUsageCommand command, {
  dynamic extra,
}) async {
  sendEvent(
    GetStorageUsageEvent(
      mediaUsage: await GetIt.I.get<StorageService>().computeUsedMediaStorage(),
      stickerUsage:
          await GetIt.I.get<StorageService>().computeUsedStickerStorage(),
    ),
    id: extra as String,
  );
}

Future<void> performOldMediaFileDeletion(
  DeleteOldMediaFilesCommand command, {
  dynamic extra,
}) async {
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  await GetIt.I.get<StorageService>().deleteOldMediaFiles(command.timeOffset);

  sendEvent(
    DeleteOldMediaFilesDoneEvent(
      newUsage: await GetIt.I.get<StorageService>().computeUsedMediaStorage(),
      conversations: (await GetIt.I
              .get<ConversationService>()
              .loadConversations(accountJid!))
          .where((c) => c.open)
          .toList(),
    ),
    id: extra as String,
  );
}

Future<void> performGetPagedStickerPacks(
  GetPagedStickerPackCommand command, {
  dynamic extra,
}) async {
  final result = await GetIt.I.get<StickersService>().getPaginatedStickerPacks(
        command.olderThan,
        command.timestamp,
        command.includeStickers,
      );

  sendEvent(
    PagedStickerPackResult(
      stickerPacks: result,
    ),
    id: extra as String,
  );
}

Future<void> performGetStickerPackById(
  GetStickerPackByIdCommand command, {
  dynamic extra,
}) async {
  sendEvent(
    GetStickerPackByIdResult(
      stickerPack: await GetIt.I.get<StickersService>().getStickerPackById(
            command.id,
          ),
    ),
    id: extra as String,
  );
}

Future<void> performDebugCommand(
  DebugCommand command, {
  dynamic extra,
}) async {
  final conn = GetIt.I.get<XmppConnection>();

  if (command.id == debug.DebugCommand.clearStreamResumption.id) {
    // Disconnect
    await conn.disconnect();

    // Reset stream management
    await conn.getManagerById<StreamManagementManager>(smManager)!.resetState();

    // Reconnect
    await conn.connect(
      shouldReconnect: true,
      waitForConnection: true,
    );
  } else if (command.id == debug.DebugCommand.requestRoster.id) {
    await conn
        .getManagerById<RosterManager>(rosterManager)!
        .requestRoster(useRosterVersion: false);
  } else if (command.id == debug.DebugCommand.logAvailableMediaFiles.id) {
    final db = GetIt.I.get<DatabaseService>().database;
    final results = await db.rawQuery(
      '''
      SELECT
        path,
        id
      FROM
        $fileMetadataTable AS fmt
      WHERE
        AND NOT EXISTS (SELECT id from $stickersTable WHERE file_metadata_id = fmt.id)
        AND path IS NOT NULL
      ''',
    );
    Logger.root.finest(results);
  }
}

Future<void> performJoinGroupchat(
  JoinGroupchatCommand command, {
  dynamic extra,
}) async {
  final id = extra as String;
  final jid = command.jid;
  final nick = command.nick;
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final cs = GetIt.I.get<ConversationService>();
  final conversation = await cs.getConversationByJid(jid, accountJid!);
  if (conversation != null) {
    await cs.createOrUpdateConversation(
      jid,
      accountJid,
      update: (c) async {
        final newConversation = await cs.updateConversation(
          jid,
          accountJid,
          open: true,
          lastChangeTimestamp: DateTime.now().millisecondsSinceEpoch,
        );

        sendEvent(
          JoinGroupchatResult(
            conversation: newConversation,
          ),
          id: id,
        );

        return newConversation;
      },
    );

    // The conversation was closed (we left the groupchat), so join it again.
    await GetIt.I.get<GroupchatService>().joinRoom(
          JID.fromString(conversation.jid),
          accountJid,
          conversation.groupchatDetails!.nick,
        );
  } else {
    // We did not have a conversation with that JID.
    await cs.createOrUpdateConversation(
      jid,
      accountJid,
      create: () async {
        // Create
        final css = GetIt.I.get<ContactsService>();
        final contactId = await css.getContactIdForJid(jid);
        final prefs = await GetIt.I.get<PreferencesService>().getPreferences();
        final newConversation = await cs.addConversationFromData(
          accountJid,
          jid.split('@')[0],
          null,
          ConversationType.groupchat,
          null,
          jid,
          0,
          DateTime.now().millisecondsSinceEpoch,
          true,
          prefs.defaultMuteState,
          prefs.enableOmemoByDefault,
          contactId,
          await css.getProfilePicturePathForJid(jid),
          await css.getContactDisplayName(contactId),
          GroupchatDetails(
            jid,
            accountJid,
            nick,
          ),
        );
        sendEvent(
          JoinGroupchatResult(
            conversation: newConversation,
          ),
          id: id,
        );

        return newConversation;
      },
    );

    // Join the room.
    final joinRoomResult = await GetIt.I.get<GroupchatService>().joinRoom(
          JID.fromString(jid),
          accountJid,
          nick,
        );
    if (joinRoomResult.isType<GroupchatErrorType>()) {
      sendEvent(
        ErrorEvent(errorId: joinRoomResult.get<GroupchatErrorType>().value),
        id: id,
      );
    }
  }
}

Future<void> performFetchRecipientInformation(
  FetchRecipientInformationCommand command, {
  dynamic extra,
}) async {
  final items = List<SendFilesRecipient>.empty(growable: true);
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final rs = GetIt.I.get<RosterService>();
  final cs = GetIt.I.get<ConversationService>();
  for (final jid in command.jids) {
    // First try to find a roster item
    final rosterItem = await rs.getRosterItemByJid(jid, accountJid!);
    if (rosterItem != null) {
      items.add(
        SendFilesRecipient(
          rosterItem.jid,
          await rosterItem.titleWithOptionalContactService,
          rosterItem.avatarPath,
          rosterItem.avatarHash,
          rosterItem.contactId != null,
        ),
      );
      continue;
    }

    // Next, try to find a conversation
    final conversation = await cs.getConversationByJid(jid, accountJid);
    if (conversation != null) {
      items.add(
        SendFilesRecipient(
          conversation.jid,
          await conversation.titleWithOptionalContactService,
          conversation.avatarPath,
          conversation.avatarHash,
          conversation.contactId != null,
        ),
      );
      continue;
    }
  }

  sendEvent(
    FetchRecipientInformationResult(items: items),
    id: extra as String,
  );
}

Future<void> performConversationExited(
  ExitConversationCommand command, {
  dynamic extra,
}) async {
  // Send a gone marker according to the specified rules
  final cs = GetIt.I.get<ConversationService>();
  await cs.sendChatState(
    ConversationType.fromString(command.conversationType),
    cs.activeConversationJid!,
    ChatState.gone,
  );

  // Reset the active conversation
  cs.activeConversationJid = null;
}

Future<void> performGetMembers(
  GetMembersForGroupchatCommand command, {
  dynamic extra,
}) async {
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final gs = GetIt.I.get<GroupchatService>();

  // TODO(Unknown): Page this request
  sendEvent(
    GroupchatMembersResult(
      members: await gs.getMembers(
        JID.fromString(command.jid),
        accountJid!,
      ),
    ),
    id: extra as String,
  );
}

Future<void> performConversationSearch(
  PerformConversationSearch command, {
  dynamic extra,
}) async {
  final accountJid = await GetIt.I.get<XmppStateService>().getAccountJid();
  final cs = GetIt.I.get<ConversationService>();

  sendEvent(
    ConversationSearchResult(
      results: await cs.searchConversations(accountJid!, command.text),
    ),
    id: extra as String,
  );
}

Future<void> performSetConversationFavourite(
  ConversationSetFavourite command, {
  dynamic extra,
}) async {
  final cs = GetIt.I.get<ConversationService>();
  final newConversation = await cs.createOrUpdateConversation(
    command.jid,
    command.accountJid,
    update: (Conversation conversation) {
      return cs.updateConversation(
        command.jid,
        command.accountJid,
        favourite: command.state,
      );
    },
  );
  sendEvent(
    ConversationUpdatedEvent(conversation: newConversation!),
  );
}
