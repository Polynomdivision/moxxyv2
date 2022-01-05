import "dart:collection";

import "package:moxxyv2/xmpp/events.dart";
import "package:moxxyv2/xmpp/namespaces.dart";
import "package:moxxyv2/xmpp/connection.dart";
import "package:moxxyv2/xmpp/stanzas/stanza.dart";

class XmppRosterItem {
  final String jid;
  final String? name;
  final String subscription;

  XmppRosterItem({ required this.jid, required this.subscription, this.name });
}

class RosterRequestResult {
  List<XmppRosterItem> items;
  String? ver;

  RosterRequestResult({ required this.items, this.ver });
}

class RosterPushEvent extends XmppEvent {
  final XmppRosterItem item;
  final String? ver;

  RosterPushEvent({ required this.item, this.ver });
}

enum RosterItemNotFoundTrigger {
  REMOVE
}

class RosterItemNotFoundEvent extends XmppEvent {
  final String jid;
  final RosterItemNotFoundTrigger trigger;

  RosterItemNotFoundEvent({ required this.jid, required this.trigger });
}

bool handleRosterPush(XmppConnection conn, Stanza stanza) {
  // TODO: Test
  // Ignore
  if (stanza.attributes["from"] != null && stanza.attributes["from"] != conn.settings.jid) {
    return true;
  }

  print("Received roster push");
  
  // TODO: Handle the real roster push stuff and move it out of the repository
  // NOTE: StanzaHandler gurantees that this is != null
  final query = stanza.firstTag("query", xmlns: ROSTER_XMLNS)!;
  final item = query.firstTag("item");

  if (item == null) {
    print("Error: Received empty roster push: " + stanza.toXml());
    // TODO: Error reply
    return true;
  }

  conn.sendEvent(RosterPushEvent(
      item: XmppRosterItem(
        jid: item.attributes["jid"]!,
        subscription: item.attributes["subscription"]!,
        name: item.attributes["name"], 
      ),
      ver: query.attributes["ver"]
  ));
  conn.sendStanza(stanza.reply());
  
  return true;
}