import "package:isar/isar.dart";
import "package:moxxyv2/isar.g.dart";

@Collection()
@Name("RosterItem")
class RosterItem {
  int? id;

  late String jid;

  late String title;

  late String avatarUrl;
}