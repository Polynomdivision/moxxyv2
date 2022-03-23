import "package:moxxyv2/shared/eventhandler.dart";
import "package:moxxyv2/shared/backgroundsender.dart";
import "package:moxxyv2/shared/awaitabledatasender.dart";
import "package:moxxyv2/shared/events.dart";

import "package:logging/logging.dart";
import "package:get_it/get_it.dart";
import "package:flutter_background_service/flutter_background_service.dart";

void setupEventHandler() {
  final handler = EventHandler();
  handler.addMatchers([]);

  GetIt.I.registerSingleton<EventHandler>(handler);

  // Make sure that we handle events from flutter_background_service
  FlutterBackgroundService().onDataReceived.listen((Map<String, dynamic>? json) async {
      final log = GetIt.I.get<Logger>();
      if (json == null) {
        log.warning("Received null from the background service. Ignoring...");
        return;
      }

      log.finest("S2F: $json");
      
      // NOTE: This feels dirty, but we gotta do it
      final event = getEventFromJson(json["data"]!)!;
      final data = DataWrapper<BackgroundEvent>(
        json["id"]!,
        event
      );
      
      // First attempt to deal with awaitables
      bool found = false;
      found = await GetIt.I.get<BackgroundServiceDataSender>().onData(data);
      if (found) return;

      // Then run the event handlers
      found = GetIt.I.get<EventHandler>().run(event);
      if (found) return;

      log.warning("Failed to match event");
  });
}