import "package:moxxyv2/xmpp/jid.dart";
import "package:moxxyv2/xmpp/stanza.dart";
import "package:moxxyv2/xmpp/connection.dart";
import "package:moxxyv2/xmpp/xeps/xep_0030/helpers.dart";
import "package:moxxyv2/xmpp/xeps/xep_0060.dart";
import "package:moxxyv2/xmpp/xeps/xep_0066.dart";
import "package:moxxyv2/xmpp/xeps/xep_0359.dart";
import "package:moxxyv2/xmpp/xeps/xep_0385.dart";
import "package:moxxyv2/xmpp/xeps/xep_0447.dart";
import "package:moxxyv2/xmpp/xeps/xep_0461.dart";

abstract class XmppEvent {}

/// Triggered when the connection state of the [XmppConnection] has
/// changed.
class ConnectionStateChangedEvent extends XmppEvent {
  final XmppConnectionState state;
  final bool resumed;

  ConnectionStateChangedEvent({ required this.state, required this.resumed });
}

/// Triggered when we encounter a stream error.
class StreamErrorEvent extends XmppEvent {
  final String error;

  StreamErrorEvent({ required this.error });
}

/// Triggered after the SASL authentication has failed.
class AuthenticationFailedEvent extends XmppEvent {
  final String saslError;

  AuthenticationFailedEvent({ required this.saslError });
}

/// Triggered when we want to ping the connection open
class SendPingEvent extends XmppEvent {}

/// Triggered when the stream resumption was successful
class StreamResumedEvent extends XmppEvent {
  final int h;

  StreamResumedEvent({ required this.h });
}

class MessageEvent extends XmppEvent {
  final String body;
  final JID fromJid;
  final String sid;
  final String? type;
  final StableStanzaId stanzaId;
  final bool isCarbon;
  final bool deliveryReceiptRequested;
  final bool isMarkable;
  final OOBData? oob;
  final StatelessFileSharingData? sfs;
  final StatelessMediaSharingData? sims;
  final ReplyData? reply;

  MessageEvent({
      required this.body,
      required this.fromJid,
      required this.sid,
      required this.stanzaId,
      required this.isCarbon,
      required this.deliveryReceiptRequested,
      required this.isMarkable,
      this.type,
      this.oob,
      this.sfs,
      this.sims,
      this.reply
  });
}

/// Triggered when a client responds to our delivery receipt request
class DeliveryReceiptReceivedEvent extends XmppEvent {
  final JID from;
  final String id;

  DeliveryReceiptReceivedEvent({ required this.from, required this.id });
}

class ChatMarkerEvent extends XmppEvent {
  final JID from;
  final String type;
  final String id;

  ChatMarkerEvent({
      required this.type,
      required this.from,
      required this.id,
  });
}

// Triggered when we received a Stream resumption ID
class StreamManagementEnabledEvent extends XmppEvent {
  final String resource;
  final String? id;
  final String? location;

  StreamManagementEnabledEvent({
      required this.resource,
      this.id,
      this.location
  });
}

/// Triggered when we bound a resource
class ResourceBindingSuccessEvent extends XmppEvent {
  final String resource;

  ResourceBindingSuccessEvent({ required this.resource });
}

/// Triggered when we receive presence
class PresenceReceivedEvent extends XmppEvent {
  final JID jid;
  final Stanza presence;

  PresenceReceivedEvent(this.jid, this.presence);
}

/// Triggered when we are starting an connection attempt
class ConnectingEvent extends XmppEvent {}

/// Triggered when we found out what the server supports
class ServerDiscoDoneEvent extends XmppEvent {}

class ServerItemDiscoEvent extends XmppEvent {
  final DiscoInfo info;
  final String jid;

  ServerItemDiscoEvent({ required this.info, required this.jid });
}

/// Triggered when we receive a subscription request
class SubscriptionRequestReceivedEvent extends XmppEvent {
  final JID from;

  SubscriptionRequestReceivedEvent({ required this.from });
}

/// Triggered when we receive a new or updated avatar
class AvatarUpdatedEvent extends XmppEvent {
  final String jid;
  final String base64;
  final String hash;

  AvatarUpdatedEvent({ required this.jid, required this.base64, required this.hash });
}

/// Triggered when a PubSub notification has been received
class PubSubNotificationEvent extends XmppEvent {
  final PubSubItem item;
  final String from;

  PubSubNotificationEvent({ required this.item, required this.from });
}

/// Triggered by the StreamManagementManager if a message stanza has been acked
class MessageAckedEvent extends XmppEvent {
  final String id;
  final String to;

  MessageAckedEvent({ required this.id, required this.to });
}

/// Triggered when receiving a push of the blocklist
class BlocklistBlockPushEvent extends XmppEvent {
  final List<String> items;

  BlocklistBlockPushEvent({ required this.items });
}

/// Triggered when receiving a push of the blocklist
class BlocklistUnblockPushEvent extends XmppEvent {
  final List<String> items;

  BlocklistUnblockPushEvent({ required this.items });
}

/// Triggered when receiving a push of the blocklist
class BlocklistUnblockAllPushEvent extends XmppEvent {
  BlocklistUnblockAllPushEvent();
}
