import 'package:freezed_annotation/freezed_annotation.dart';

part 'omemo_key.freezed.dart';
part 'omemo_key.g.dart';

@freezed
class OmemoKey with _$OmemoKey {
  factory OmemoKey(
    String fingerprint,
  ) = _OmemoKey;

  /// JSON
  factory OmemoKey.fromJson(Map<String, dynamic> json) => _$OmemoKeyFromJson(json);
}