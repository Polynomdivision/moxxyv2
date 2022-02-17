import "dart:async";

import "package:moxxyv2/service/repositories/database.dart";
import "package:moxxyv2/service/repositories/xmpp.dart";
import "package:moxxyv2/service/repositories/roster.dart";
import "package:moxxyv2/xmpp/connection.dart";
import "package:moxxyv2/xmpp/settings.dart";
import "package:moxxyv2/xmpp/jid.dart";
import "package:moxxyv2/xmpp/presence.dart";
import "package:moxxyv2/xmpp/message.dart";
import "package:moxxyv2/xmpp/managers/namespaces.dart";
import "package:moxxyv2/xmpp/xeps/xep_0352.dart";
import "package:moxxyv2/service/managers/roster.dart";
import "package:moxxyv2/service/managers/disco.dart";
import "package:moxxyv2/service/managers/stream.dart";
import "package:moxxyv2/shared/logging.dart";

import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter_background_service/flutter_background_service.dart";
import "package:get_it/get_it.dart";
import "package:awesome_notifications/awesome_notifications.dart";
import "package:isar/isar.dart";
import "package:path_provider/path_provider.dart";
import "package:logging/logging.dart";

import "package:moxxyv2/service/db/conversation.dart";
import "package:moxxyv2/service/db/roster.dart";
import "package:moxxyv2/service/db/message.dart";

Future<void> initializeServiceIfNeeded() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = FlutterBackgroundService();
  if (await service.isServiceRunning()) {
    GetIt.I.get<Logger>().info("Stopping background service");

    if (kDebugMode) {
      //service.stopBackgroundService();
    } else {
      return;
    }
  }

  GetIt.I.get<Logger>().info("Initializing service");
  await initializeService();
}

void Function(Map<String, dynamic>) sendDataMiddleware(FlutterBackgroundService srv) {
  return (data) {
    // NOTE: *S*erver to *F*oreground
    GetIt.I.get<Logger>().fine("S2F: " + data.toString());

    srv.sendData(data);
  };
}

Future<void> performPreStart(void Function(Map<String, dynamic>) middleware) async {
  final xmpp = GetIt.I.get<XmppRepository>();
  final account = await xmpp.getAccountData();
  final settings = await xmpp.loadConnectionSettings();

  if (account!= null && settings != null) {
    await GetIt.I.get<RosterRepository>().loadRosterFromDatabase();

    middleware({
        "type": "PreStartResult",
        "state": "logged_in",
        "jid": account.jid,
        "displayName": account.displayName,
        "avatarUrl": account.avatarUrl
    });
  } else {
    middleware({
        "type": "PreStartResult",
        "state": "not_logged_in"
    });
  }
}

Future<Isar> openDatabase() async {
  final dir = await getApplicationSupportDirectory();
  return await Isar.open(
    schemas: [
      DBConversationSchema,
      DBRosterItemSchema,
      DBMessageSchema
    ],
    directory: dir.path
  );
}

void setupLogging() {
  Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen((record) { 
      final logMessage = "[${record.level.name}] (${record.loggerName}) ${record.time}: ${record.message}";
      if (GetIt.I.isRegistered<UDPLogger>()) {
        final udp = GetIt.I.get<UDPLogger>();
        if (udp.isEnabled()) {
          udp.sendLog(logMessage, record.time.millisecondsSinceEpoch, record.level.name);
        }
      }

      if (kDebugMode) {
        // ignore: avoid_print
        print(logMessage);
      }
  });
}

Future<void> initUDPLogger() async {
  final xmpp = GetIt.I.get<XmppRepository>();
  if (await xmpp.getDebugEnabled() ?? false) {
    GetIt.I.get<Logger>().finest("UDPLogger created");
  
    final port = await xmpp.getDebugPort();
    final ip = await xmpp.getDebugIp();
    final passphrase = await xmpp.getDebugPassphrase();

    if (port != null && ip != null && passphrase != null) {
      GetIt.I.get<UDPLogger>().init(passphrase, ip, port);
    }
  } else {
    GetIt.I.get<UDPLogger>().setEnabled(false);
  }
}

void onStart() {
  WidgetsFlutterBinding.ensureInitialized();

  setupLogging();
  GetIt.I.registerSingleton<Logger>(Logger("XmppService"));
  
  AwesomeNotifications().initialize(
    // TODO: Add icon
    null,
    [
      NotificationChannel(
        channelGroupKey: "messages",
        channelKey: "message_channel",
        channelName: "Message notifications",
        channelDescription: "Notifications for messages go here",
        importance: NotificationImportance.High
      )
    ],
    debug: true
  );

  final service = FlutterBackgroundService();
  service.onDataReceived.listen(handleEvent);
  service.setNotificationInfo(title: "Moxxy", content: "Connecting...");

  GetIt.I.get<Logger>().finest("Running...");
  
  (() async {
      final middleware = sendDataMiddleware(service);

      // Register singletons
      GetIt.I.registerSingleton<UDPLogger>(UDPLogger());

      final db = DatabaseRepository(isar: await openDatabase(), sendData: middleware);
      GetIt.I.registerSingleton<DatabaseRepository>(db); 

      final xmpp = XmppRepository(sendData: (data) {
          if (data["type"] == "ConnectionStateEvent") {
            if (data["state"] == XmppConnectionState.connected.toString().split(".")[1]) {
              FlutterBackgroundService().setNotificationInfo(title: "Moxxy", content: "Ready to receive messages");
            } else if (data["state"] == XmppConnectionState.connecting.toString().split(".")[1]) {
              FlutterBackgroundService().setNotificationInfo(title: "Moxxy", content: "Connecting...");
            } else {
              FlutterBackgroundService().setNotificationInfo(title: "Moxxy", content: "Disconnected");
            }
          }

          middleware(data);
      });
      GetIt.I.registerSingleton<XmppRepository>(xmpp);

      // Init the UDPLogger
      await initUDPLogger();

      GetIt.I.registerSingleton<RosterRepository>(RosterRepository(sendData: service.sendData));

      final connection = XmppConnection();
      connection.registerManager(MoxxyStreamManagementManager());
      connection.registerManager(MoxxyDiscoManager());
      connection.registerManager(MessageManager());
      connection.registerManager(MoxxyRosterManger());
      connection.registerManager(PresenceManager());
      connection.registerManager(CSIManager());
      GetIt.I.registerSingleton<XmppConnection>(connection);

      final account = await xmpp.getAccountData();
      final settings = await xmpp.loadConnectionSettings();

      if (account!= null && settings != null) {
        xmpp.connect(settings, false);
      }
      await performPreStart(middleware);
  })();
}

Future<FlutterBackgroundService> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    // TODO: iOS
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onBackground: () {},
      onForeground: () {}
    ),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true
    )
  );

  return service;
}

void handleEvent(Map<String, dynamic>? data) {
  // NOTE: *F*oreground to *S*ervice
  GetIt.I.get<Logger>().fine("F2S: " + data.toString());

  switch (data!["type"]) {
    case "LoadConversationsAction": {
      GetIt.I.get<DatabaseRepository>().loadConversations();
    }
    break;
    case "LoadRosterAction": {
      GetIt.I.get<DatabaseRepository>().loadRosterItems(notify: true);
    }
    break;
    case "PerformLoginAction": {
      GetIt.I.get<Logger>().fine("Performing login");
      GetIt.I.get<XmppRepository>().connect(ConnectionSettings(
          jid: BareJID.fromString(data["jid"]!),
          password: data["password"]!,
          useDirectTLS: data["useDirectTLS"]!,
          allowPlainAuth: data["allowPlainAuth"]
      ), true);
    }
    break;
    case "LoadMessagesForJidAction": {
      GetIt.I.get<DatabaseRepository>().loadMessagesForJid(data["jid"]);
    }
    break;
    case "SetCurrentlyOpenChatAction": {
      GetIt.I.get<XmppRepository>().setCurrentlyOpenedChatJid(data["jid"]);
    }
    break;
    case "AddToRosterAction": {
      final String jid = data["jid"];
      (() async {
          final roster = GetIt.I.get<RosterRepository>();
          if (await roster.isInRoster(jid)) {
            FlutterBackgroundService().sendData({
                "type": "AddToRosterResult",
                "result": "error",
                "msg": "Already in contact list"
            });
            return;
          }

          final db = GetIt.I.get<DatabaseRepository>();
          final conversation = await db.getConversationByJid(jid);
          if (conversation != null) {
            final c = await db.updateConversation(id: conversation.id, open: true);
            FlutterBackgroundService().sendData({
                "type": "ConversationUpdatedEvent",
                "conversation": c.toJson()
            });
          } else {
            final c = await db.addConversationFromData(
              jid.split("@")[0],
              "",
              "",
              jid,
              0,
              -1,
              [],
              true
            );
            FlutterBackgroundService().sendData({
                "type": "ConversationCreatedEvent",
                "conversation": c.toJson()
            });
          }

          roster.addToRoster("", jid, jid.split("@")[0]);
          FlutterBackgroundService().sendData({
              "type": "AddToRosterResult",
              "result": "success",
              "jid": jid
          });
      })();
    }
    break;
    case "RemoveRosterItemAction": {
      (() async {
          final jid = data["jid"]!;
          //await GetIt.I.get<DatabaseRepository>().removeRosterItemByJid(jid, nullOkay: true);
          await GetIt.I.get<XmppConnection>().getManagerById(rosterManager)!.removeFromRoster(jid);
          await GetIt.I.get<XmppConnection>().getManagerById(rosterManager)!.sendUnsubscriptionRequest(jid);
      })();
    }
    break;
    case "SendMessageAction": {
      GetIt.I.get<XmppRepository>().sendMessage(body: data["body"]!, jid: data["jid"]!);
    }
    break;
    case "SetCSIState": {
      final csi = GetIt.I.get<XmppConnection>().getManagerById(csiManager);
      if (csi == null) {
        return;
      }

      if (data["state"] == "foreground") {
        csi.setActive();
      } else {
        csi.setInactive();
      }
    }
    break;
    case "PerformPrestartAction": {
      // TODO: This assumes that we are ready if we receive this event
      performPreStart(FlutterBackgroundService().sendData);
    }
    break;
    case "DebugSetEnabledAction": {
      (() async {
          await GetIt.I.get<XmppRepository>().saveDebugEnabled(data["enabled"] as bool);
          initUDPLogger();
      })();
    }
    break;
    case "DebugSetIpAction": {
      (() async {
          await GetIt.I.get<XmppRepository>().saveDebugIp(data["ip"] as String);
          initUDPLogger();
      })();
    }
    break;
    case "DebugSetPortAction": {
      (() async {
          await GetIt.I.get<XmppRepository>().saveDebugPort(data["port"] as int);
          initUDPLogger();
      })();
    }
    break;
    case "DebugSetPassphraseAction": {
      (() async {
          await GetIt.I.get<XmppRepository>().saveDebugPassphrase(data["passphrase"] as String);
          initUDPLogger();
      })();
    }
    break;
    case "__STOP__": {
      FlutterBackgroundService().stopBackgroundService();
    }
    break;
  }
}
