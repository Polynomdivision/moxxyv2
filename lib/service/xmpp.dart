import "dart:async";

import "package:moxxyv2/backend/account.dart";
import "package:moxxyv2/repositories/database.dart";
import "package:moxxyv2/repositories/xmpp.dart";
import "package:moxxyv2/xmpp/connection.dart";
import "package:moxxyv2/xmpp/settings.dart";
import "package:moxxyv2/xmpp/jid.dart";

import "package:flutter/material.dart";
import "package:flutter_background_service/flutter_background_service.dart";
import "package:get_it/get_it.dart";
import "package:isar/isar.dart";

import "package:moxxyv2/isar.g.dart";

Future<void> initializeServiceIfNeeded() async {
  WidgetsFlutterBinding.ensureInitialized();

  GetIt.I.registerSingleton<FlutterBackgroundService>(await initializeService());
}

void Function(Map<String, dynamic>) sendDataMiddleware(FlutterBackgroundService srv) {
  return (data) {
    // NOTE: *S*erver to *F*oreground
    print("[S2F] " + data.toString());

    srv.sendData(data);
  };
}

void onStart() {
  WidgetsFlutterBinding.ensureInitialized();
  final service = FlutterBackgroundService();
  service.onDataReceived.listen(handleEvent);
  service.setNotificationInfo(title: "Moxxy", content: "Connecting...");

  service.sendData({ "type": "__LOG__", "log": "Running" });

  GetIt.I.registerSingleton<FlutterBackgroundService>(service);
  
  (() async {
      final middleware = sendDataMiddleware(service);

      // Register singletons
      final db = DatabaseRepository(isar: await openIsar(), sendData: middleware);
      GetIt.I.registerSingleton<DatabaseRepository>(db); 

      final xmpp = XmppRepository(sendData: (data) {
          if (data["type"] == "ConnectionStateEvent") {
            if (data["state"] == "CONNECTED") {
              service.setNotificationInfo(title: "Moxxy", content: "Ready to receive messages");
            } else if (data["state"] == "CONNECTING") {
              service.setNotificationInfo(title: "Moxxy", content: "Connecting...");
            } else {
              service.setNotificationInfo(title: "Moxxy", content: "Disconnected");
            }
          }

          middleware(data);
      });
      GetIt.I.registerSingleton<XmppRepository>(xmpp);

      final connection = XmppConnection(log: (data) {
          service.sendData({ "type": "__LOG__", "log": data });
      });
      GetIt.I.registerSingleton<XmppConnection>(connection);

      final account = await getAccountData();
      final settings = await xmpp.loadConnectionSettings();

      if (account!= null && settings != null) {
        /* TODO
        await GetIt.I.get<RosterRepository>().loadRosterFromDatabase();
        */
        middleware({
            "type": "__LOG__",
            "log": "Connecting..."
        });
        xmpp.connect(settings, false);
        middleware({
            "type": "PreStartResult",
            "state": "logged_in"
        });
      } else {
        middleware({
            "type": "PreStartResult",
            "state": "not_logged_in"
        });
      }
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
  print("[F2S] " + data.toString());

  switch (data!["type"]) {
    case "LoadConversationsAction": {
      GetIt.I.get<DatabaseRepository>().loadConversations();
    }
    break;
    case "PerformLoginAction": {
      GetIt.I.get<FlutterBackgroundService>().sendData({ "type": "__LOG__", "log": "Performing login"});
      GetIt.I.get<XmppRepository>().connect(ConnectionSettings(
          jid: BareJID.fromString(data["jid"]!),
          password: data["password"]!,
          useDirectTLS: data["useDirectTLS"]!,
          allowPlainAuth: data["allowPlainAuth"],
          streamResumptionSettings: StreamResumptionSettings()
      ), true);
    }
    break;
    case "__STOP__": {
      FlutterBackgroundService().stopBackgroundService();
    }
    break;
  }
}
