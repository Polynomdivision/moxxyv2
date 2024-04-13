import 'package:flutter/material.dart';
import 'package:moxxy_native/moxxy_native.dart';
import 'package:moxxyv2/shared/commands.dart';
import 'package:moxxyv2/shared/events.dart';
import 'package:moxxyv2/ui/state/sendfiles.dart';
import 'package:moxxyv2/ui/widgets/avatar.dart';

class ConversationIndicator extends StatelessWidget {
  const ConversationIndicator(this.recipients, {super.key});

  /// The list of JIDs for which we need an avatar and title.
  final List<SendFilesRecipient> recipients;

  @override
  Widget build(BuildContext context) {
    final showAvatar = recipients.length == 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAvatar)
              CachingXMPPAvatar(
                jid: recipients.first.jid,
                borderRadius: 20,
                size: 40,
                hasContactId: recipients.first.hasContactId,
                // TODO(Unknown): This is not always correct.
                isGroupchat: false,
                path: recipients.first.avatar,
                hash: recipients.first.avatarHash,
                altIcon: recipients.first.jid == '' ? Icons.notes : null,
              ),
            Padding(
              padding: EdgeInsets.only(
                left: showAvatar ? 8 : 10,
                top: showAvatar ? 0 : 10,
                bottom: showAvatar ? 0 : 10,
              ),
              child: Text(
                recipients.map((r) => r.title).join(', '),
                maxLines: recipients.length == 1 ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FetchingConversationIndicator extends StatelessWidget {
  const FetchingConversationIndicator(this.conversationJids, {super.key});

  final List<String> conversationJids;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: getForegroundService().send(
        FetchRecipientInformationCommand(jids: conversationJids),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        return ConversationIndicator(
          (snapshot.data! as FetchRecipientInformationResult).items,
        );
      },
    );
  }
}
