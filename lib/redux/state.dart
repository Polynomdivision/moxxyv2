import "dart:collection";
import "package:moxxyv2/redux/conversation/reducers.dart";
import "package:moxxyv2/redux/conversations/reducers.dart";
import "package:moxxyv2/redux/login/reducers.dart";
import "package:moxxyv2/redux/addcontact/reducers.dart";
import "package:moxxyv2/redux/registration/reducers.dart";
import "package:moxxyv2/redux/postregister/reducers.dart";
import "package:moxxyv2/redux/profile/reducers.dart";
import "package:moxxyv2/redux/account/reducers.dart";
import "package:moxxyv2/ui/pages/login/state.dart";
import "package:moxxyv2/ui/pages/conversation/state.dart";
import "package:moxxyv2/ui/pages/addcontact/state.dart";
import "package:moxxyv2/ui/pages/register/state.dart";
import "package:moxxyv2/ui/pages/postregister/state.dart";
import "package:moxxyv2/ui/pages/profile/state.dart";
import "package:moxxyv2/redux/account/state.dart";
import "package:moxxyv2/models/message.dart";
import "package:moxxyv2/models/conversation.dart";

MoxxyState moxxyReducer(MoxxyState state, dynamic action) {
  return MoxxyState(
    messages: messageReducer(state.messages, action),
    conversations: conversationReducer(state.conversations, action),
    loginPageState: loginReducer(state.loginPageState, action),
    conversationPageState: conversationPageReducer(state.conversationPageState, action),
    addContactPageState: addContactPageReducer(state.addContactPageState, action),
    registerPageState: registerReducer(state.registerPageState, action),
    postRegisterPageState: postRegisterReducer(state.postRegisterPageState, action),
    profilePageState: profileReducer(state.profilePageState, action),
    accountState: accountReducer(state.accountState, action)
  );
}

class MoxxyState {
  final HashMap<String, List<Message>> messages;
  final List<Conversation> conversations;
  final LoginPageState loginPageState;
  final ConversationPageState conversationPageState;
  final AddContactPageState addContactPageState;
  final RegisterPageState registerPageState;
  final PostRegisterPageState postRegisterPageState;
  final ProfilePageState profilePageState;
  final AccountState accountState;

  const MoxxyState({ required this.messages, required this.conversations, required this.loginPageState, required this.conversationPageState, required this.addContactPageState, required this.registerPageState, required this.postRegisterPageState, required this.profilePageState, required this.accountState });
  // TODO: providerIndex should be random
  MoxxyState.initialState() : messages = HashMap(), conversations = List.empty(growable: true), loginPageState = LoginPageState(doingWork: false, showPassword: false), conversationPageState = ConversationPageState(showSendButton: false), addContactPageState = AddContactPageState(doingWork: false), registerPageState = RegisterPageState(providerIndex: 0, doingWork: false), postRegisterPageState = PostRegisterPageState(showSnackbar: false), profilePageState = ProfilePageState(showSnackbar: false), accountState = AccountState(jid: "", avatarUrl: "", displayName: "");
}
