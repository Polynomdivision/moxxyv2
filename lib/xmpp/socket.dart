import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:moxdns/moxdns.dart';
import 'package:moxxyv2/xmpp/rfcs/rfc_2782.dart';

// NOTE: https://www.iana.org/assignments/tls-extensiontype-values/tls-extensiontype-values.xhtml#alpn-protocol-ids
const xmppClientALPNId = 'xmpp-client';

abstract class XmppSocketEvent {}

/// Triggered by the socket when an error occurs.
class XmppSocketErrorEvent extends XmppSocketEvent {

  XmppSocketErrorEvent(this.error);
  final Object error;
}

/// Triggered when the socket is closed
class XmppSocketClosureEvent extends XmppSocketEvent {}

/// This class is the base for a socket that XmppConnection can use.
abstract class BaseSocketWrapper {
  /// This must return the unbuffered string stream that the socket receives.
  Stream<String> getDataStream();

  /// This must return events generated by the socket.
  /// See sub-classes of [XmppSocketEvent] for possible events.
  Stream<XmppSocketEvent> getEventStream();
  
  /// This must close the socket but not the streams so that the same class can be
  /// reused by calling [this.connect] again.
  void close();

  /// Write [data] into the socket. If [redact] is not null, then [redact] will be
  /// logged instead of [data].
  void write(String data, { String? redact });
  
  /// This must connect to [host]:[port] and initialize the streams accordingly.
  /// [domain] is the domain that TLS should be validated against, in case the Socket
  /// provides TLS encryption. Returns true if the connection has been successfully
  /// established. Returns false if the connection has failed.
  Future<bool> connect(String domain, { String? host, int? port });

  /// Returns true if the socket is secured, e.g. using TLS.
  bool isSecure();

  /// Upgrades the connection into a secure version, e.g. by performing a TLS upgrade.
  /// May do nothing if the connection is always secure.
  /// Returns true if the socket has been successfully upgraded. False otherwise.
  Future<bool> secure(String domain);

  /// Returns true if whitespace pings are allowed. False if not.
  bool whitespacePingAllowed();

  /// Returns true if it manages its own keepalive pings, like websockets. False if not.
  bool managesKeepalives();
}

/// TCP socket implementation for XmppConnection
class TCPSocketWrapper extends BaseSocketWrapper {
  
  TCPSocketWrapper()
  : _log = Logger('TCPSocketWrapper'),
    _dataStream = StreamController.broadcast(),
    _eventStream = StreamController.broadcast(),
    _secure = false;
  Socket? _socket;
  final StreamController<String> _dataStream;
  final StreamController<XmppSocketEvent> _eventStream;
  StreamSubscription<dynamic>? _socketSubscription;

  final Logger _log;

  bool _secure;

  @override
  bool isSecure() => _secure;

  @override
  bool whitespacePingAllowed() => true;

  @override
  bool managesKeepalives() => false;

  /// Allow the socket to be destroyed by cancelling internal subscriptions.
  void destroy() {
    if (_socketSubscription != null) {
      _socketSubscription!.cancel();
    }
  }
  
  bool _onBadCertificate(dynamic certificate, String domain) {
    _log.fine('Bad certificate: ${certificate.toString()}');
    //final isExpired = certificate.endValidity.isAfter(DateTime.now());
    // TODO(Unknown): Either validate the certificate ourselves or use a platform native
    //                hostname verifier (or Dart adds it themselves)
    return false;
  }
  
  Future<bool> _xep368Connect(String domain) async {
    // TODO(Unknown): Maybe do DNSSEC one day
    final results = await MoxdnsPlugin.srvQuery('_xmpps-client._tcp.$domain', false);
    if (results.isEmpty) {
      return false;
    }

    results.sort(srvRecordSortComparator);
    for (final srv in results) {
      try {
        _log.finest('Attempting secure connection to ${srv.target}:${srv.port}...');
        _socket = await SecureSocket.connect(
          srv.target,
          srv.port,
          timeout: const Duration(seconds: 5),
          supportedProtocols: const [ xmppClientALPNId ],
          onBadCertificate: (cert) => _onBadCertificate(cert, domain),
        );

        _secure = true;
        _log.finest('Success!');
        return true;
      } on SocketException catch(e) {
        _log.finest('Failure! $e');
      }
    }

    return false;
  }
  
  Future<bool> _rfc6120Connect(String domain) async {
    // TODO(Unknown): Maybe do DNSSEC one day
    final results = await MoxdnsPlugin.srvQuery('_xmpp-client._tcp.$domain', false);
    results.sort(srvRecordSortComparator);

    for (final srv in results) {
      try {
        _log.finest('Attempting connection to ${srv.target}:${srv.port}...');
        _socket = await Socket.connect(
          srv.target,
          srv.port,
          timeout: const Duration(seconds: 5),
        );
        _log.finest('Success!');
        return true;
      } on SocketException catch(e) {
        _log.finest('Failure! $e');
        continue;
      }
    }

    return _rfc6120FallbackConnect(domain);
  }

  /// Connect to [host] with port [port] and returns true if the connection
  /// was successfully established. Does not setup the streams as this has
  /// to be done by the caller.
  Future<bool> _hostPortConnect(String host, int port) async {
    try {
      _log.finest('Attempting fallback connection to $host:$port...');
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      _log.finest('Success!');
      return true;
    } on SocketException catch(e) {
      _log.finest('Failure! $e');
      return false;
    }
  }

  /// Connect to [domain] using the default C2S port of XMPP. Returns
  /// true if the connection was successful. Does not setup the streams
  /// as [_rfc6120FallbackConnect] should only be called from
  /// [_rfc6120Connect], which already sets the streams up on a successful
  /// connection.
  Future<bool> _rfc6120FallbackConnect(String domain) async {
    return _hostPortConnect(domain, 5222);
  }

  @override
  Future<bool> secure(String domain) async {
    if (_secure) {
      _log.warning('Connection is already marked as secure. Doing nothing');
      return true;
    }

    if (_socket == null) {
      _log.severe('Failed to secure socket since _socket is null');
      return false;
    }
    
    try {
      _socket = await SecureSocket.secure(
        _socket!,
        supportedProtocols: const [ xmppClientALPNId ],
        onBadCertificate: (cert) => _onBadCertificate(cert, domain),
      );

      _secure = true;
      _setupStreams();
      return true;
    } on SocketException {
      return false;
    }
  }
  
  void _setupStreams() {
    if (_socket == null) {
      _log.severe('Failed to setup streams as _socket is null');
      return;
    }

    _socketSubscription = _socket!.listen(
      (List<int> event) {
        final data = utf8.decode(event);
        _log.finest('<== $data');
        _dataStream.add(data);
      },
      onError: (Object error) {
        _log.severe(error.toString());
        _eventStream.add(XmppSocketErrorEvent(error));
      },
    );
    // ignore: implicit_dynamic_parameter
    _socket!.done.then((_) {
        _eventStream.add(XmppSocketClosureEvent());
    });
  }
  
  @override
  Future<bool> connect(String domain, { String? host, int? port }) async {
    _secure = false;

    // Connection order:
    // 1. host:port, if given
    // 2. XEP-0368
    // 3. RFC 6120
    // 4. RFC 6120 fallback

    if (host != null && port != null) {
      _log.finest('Specific host and port given');
      if (await _hostPortConnect(host, port)) {
        _setupStreams();
        return true;
      }
    }

    if (await _xep368Connect(domain)) {
      _setupStreams();
      return true;
    }

    // NOTE: _rfc6120Connect already attempts the fallback
    if (await _rfc6120Connect(domain)) {
      _setupStreams();
      return true;
    }

    return false;
  }

  @override
  void close() {
    if (_socketSubscription != null) {
      _log.finest('Closing socket subscription');
      _socketSubscription!.cancel();
    }

    if (_socket == null) {
      _log.warning('Failed to close socket since _socket is null');
      return;
    }

    _socket!.close();
    _socket!.flush();
  }

  @override
  Stream<String> getDataStream() => _dataStream.stream.asBroadcastStream();

  @override
  Stream<XmppSocketEvent> getEventStream() => _eventStream.stream.asBroadcastStream();

  @override
  void write(Object? data, { String? redact }) {
    if (_socket == null) {
      _log.severe('Failed to write to socket as _socket is null');
      return;
    }

    if (data != null && data is String) {
      if (redact != null) {
        _log.finest('**> $redact');
      } else {
        _log.finest('==> $data');
      }
    }

    try {
      _socket!.write(data);
    } on SocketException catch (e) {
      _log.severe(e);
      _eventStream.add(XmppSocketErrorEvent(e));
    }
  }
}
