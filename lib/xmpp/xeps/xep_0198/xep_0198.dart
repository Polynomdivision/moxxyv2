import "package:moxxyv2/xmpp/stanza.dart";
import "package:moxxyv2/xmpp/events.dart";
import "package:moxxyv2/xmpp/namespaces.dart";
import "package:moxxyv2/xmpp/stringxml.dart";
import "package:moxxyv2/xmpp/managers/handlers.dart";
import "package:moxxyv2/xmpp/managers/base.dart";
import "package:moxxyv2/xmpp/managers/data.dart";
import "package:moxxyv2/xmpp/managers/namespaces.dart";
import "package:moxxyv2/xmpp/xeps/xep_0198/state.dart";
import "package:moxxyv2/xmpp/xeps/xep_0198/nonzas.dart";

import "package:mutex/mutex.dart";
import "package:meta/meta.dart";

const xmlUintMax = 4294967296; // 2**32

class StreamManagementManager extends XmppManagerBase {
  /// The queue of stanzas that are not (yet) acked
  final Map<int, Stanza> _unackedStanzas;
  /// Commitable state of the StreamManagementManager
  StreamManagementState _state;
  /// Mutex lock for _state
  final Mutex _stateMutex;
  /// If the have enabled SM on the stream yet
  bool _streamManagementEnabled;

  StreamManagementManager()
  : _state = StreamManagementState(0, 0),
    _unackedStanzas = {},
    _stateMutex = Mutex(),
    _streamManagementEnabled = false;
  
  /// Functions for testing
  @visibleForTesting
  Map<int, Stanza> getUnackedStanzas() => _unackedStanzas;
  
  /// May be overwritten by a subclass. Should save [state] so that it can be loaded again
  /// with [this.loadState].
  Future<void> commitState() async {}

  Future<void> loadState() async {}

  void setState(StreamManagementState state) {
    _state = state;
  }

  /// Resets the state such that a resumption is no longer possible without creating
  /// a new session. Primarily useful for clearing the state after disconnecting
  Future<void> resetState() async {
    await _stateMutex.protect(() async {
        setState(_state.copyWith(
            c2s: 0,
            s2c: 0,
            streamResumptionLocation: null,
            streamResumptionId: null,
        ));
        await commitState();
    });
  }
  
  StreamManagementState get state => _state;
  
  @override
  String getId() => smManager;

  @override
  String getName() => "StreamManagementManager";

  @override
  List<NonzaHandler> getNonzaHandlers() => [
    NonzaHandler(
      nonzaTag: "r",
      nonzaXmlns: smXmlns,
      callback: _handleAckRequest
    ),
    NonzaHandler(
      nonzaTag: "a",
      nonzaXmlns: smXmlns,
      callback: _handleAckResponse
    )
  ];

  @override
  List<StanzaHandler> getIncomingStanzaHandlers() => [
    StanzaHandler(
      callback: _onServerStanzaReceived
    )
  ];

  @override
  List<StanzaHandler> getOutgoingPostStanzaHandlers() => [
    StanzaHandler(
      callback: _onClientStanzaSent
    )
  ];
  
  @override
  Future<void> onXmppEvent(XmppEvent event) async {
    if (event is SendPingEvent) {
      if (isStreamManagementEnabled()) {
        _sendAckRequestPing();
      } else {
        getAttributes().sendRawXml("");
      }
    } else if (event is StreamResumedEvent) {
      _enableStreamManagement();
      await onStreamResumed(event.h);
    } else if (event is StreamManagementEnabledEvent) {
      _enableStreamManagement();

      await _stateMutex.protect(() async {
          setState(StreamManagementState(
              0,
              0,
              streamResumptionId: event.id,
              streamResumptionLocation: event.location
          ));
          await commitState();
      });
    } else if (event is ConnectingEvent) {
      _disableStreamManagement();
    }
  }

  /// Resets the enablement of stream management, but __NOT__ the internal state.
  /// This is to prevent ack requests being sent before we resume or re-enable
  /// stream management.
  void _disableStreamManagement() {
    _streamManagementEnabled = false;
  }
  
  /// Enables support for XEP-0198 stream management
  void _enableStreamManagement() {
    _streamManagementEnabled = true;
  }
  
  /// Returns whether XEP-0198 stream management is enabled
  bool isStreamManagementEnabled() => _streamManagementEnabled;

  /// To be called when receiving a <a /> nonza.
  Future<bool> _handleAckRequest(XMLNode nonza) async {
    final attrs = getAttributes();
    logger.finest("Sending ack response");
    await _stateMutex.protect(() async {
        attrs.sendNonza(StreamManagementAckNonza(_state.s2c));
    });

    return true;
  }

  /// Called when we receive an <a /> nonza from the server.
  /// This is a response to the question "How many of my stanzas have you handled".
  Future<bool> _handleAckResponse(XMLNode nonza) async {
    final h = int.parse(nonza.attributes["h"]!);

    // Return early if we acked nothing.
    // Taken from slixmpp's stream management code
    await _stateMutex.acquire();
    if (h == _state.c2s && _unackedStanzas.isEmpty) {
      _stateMutex.release();
      return true;
    }
    _stateMutex.release();

    final attrs = getAttributes();
    final sequences = _unackedStanzas.keys.toList()..sort();
    for (final height in sequences) {
      // Do nothing if the ack does not concern this stanza
      if (height > h) continue;

      final stanza = _unackedStanzas[height]!;
      _unackedStanzas.remove(height);
      if (stanza.tag == "message" && stanza.id != null) {
        attrs.sendEvent(
          MessageAckedEvent(
            id: stanza.id!,
            to: stanza.to!
          )
        );
      }
    }

    await _stateMutex.protect(() async {
        if (h > _state.c2s) {
          logger.info("C2S height jumped from ${_state.c2s} (local) to $h (remote).");
          logger.info("Proceeding with $h as local C2S counter.");

          _state = _state.copyWith(c2s: h);
          await commitState();
        }
    });

    return true;
  }

  // Just a helper function to not increment the counters above xmlUintMax
  Future<void> _incrementC2S() async {
    await _stateMutex.protect(() async {
        _state = _state.copyWith(c2s: _state.c2s + 1 % xmlUintMax);
        await commitState();
    });
  }
  Future<void> _incrementS2C() async {
    await _stateMutex.protect(() async {
        _state = _state.copyWith(s2c: _state.s2c + 1 % xmlUintMax);
        await commitState();
    });
  }
  
  /// Called whenever we receive a stanza from the server.
  Future<StanzaHandlerData> _onServerStanzaReceived(Stanza stanza, StanzaHandlerData state) async {
    await _incrementS2C();
    return state;
  }

  /// Called whenever we send a stanza.
  Future<StanzaHandlerData> _onClientStanzaSent(Stanza stanza, StanzaHandlerData state) async {
    await _incrementC2S();
    _unackedStanzas[_state.c2s] = stanza;
    
    if (isStreamManagementEnabled() && !state.retransmitted) {
      getAttributes().sendNonza(StreamManagementRequestNonza());
    }

    return state;
  }

  /// To be called when the stream has been resumed
  @visibleForTesting
  Future<void> onStreamResumed(int h) async {
    await _handleAckResponse(StreamManagementAckNonza(h));

    final stanzas = _unackedStanzas.values.toList();
    _unackedStanzas.clear();
    
    // Retransmit the rest of the queue
    final attrs = getAttributes();
    for (final stanza in stanzas) {
      attrs.sendStanza(stanza, awaitable: false, retransmitted: true);
    }
    _sendAckRequestPing();
  }

  /// Pings the connection open by send an ack request
  void _sendAckRequestPing() {
    getAttributes().sendNonza(StreamManagementRequestNonza());
  }
}
