import "package:moxxyv2/ui/widgets/topbar.dart";
import "package:moxxyv2/ui/redux/state.dart";
import "package:moxxyv2/ui/redux/preferences/actions.dart";

import "package:flutter/material.dart";
import "package:flutter_settings_ui/flutter_settings_ui.dart";
import "package:flutter_redux/flutter_redux.dart";
import "package:redux/redux.dart";
import "package:drop_down_list/drop_down_list.dart";

class NetworkPage extends StatelessWidget {
  const NetworkPage({ Key? key }): super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BorderlessTopbar.simple(title: "Network"),
      body: StoreConnector<MoxxyState, Store>(
        converter: (store) => store,
        builder: (context, store) => SettingsList(
          darkBackgroundColor: const Color(0xff303030),
          contentPadding: const EdgeInsets.all(16.0),
          sections: [
            SettingsSection(
              title: "Automatic Downloads",
              tiles: [
                SettingsTile(title: "Moxxy will automatically download files on..."),
                SettingsTile.switchTile(
                  title: "Wifi",
                  switchValue: store.state.preferencesState.autoDownloadWifi,
                  onToggle: (value) => store.dispatch(
                    SetPreferencesAction(
                      store.state.preferencesState.copyWith(
                        autoDownloadWifi: value
                      )
                    )
                  )
                ),
                SettingsTile.switchTile(
                  title: "Mobile Internet",
                  switchValue: store.state.preferencesState.autoDownloadMobile,
                  onToggle: (value) => store.dispatch(
                    SetPreferencesAction(
                      store.state.preferencesState.copyWith(
                        autoDownloadMobile: value
                      )
                    )
                  )
                ),
                SettingsTile(
                  title: "Maximum Download Size",
                  subtitle: "The maximum file size for a file to be automatically downloaded",
                  subtitleMaxLines: 2,
                  onPressed: (context) {
                    // TODO: This does not work on dark mode
                    DropDownState(
                      DropDown(
                        submitButtonText: "Okay",
                        submitButtonColor: const Color.fromRGBO(70, 76, 222, 1),
                        bottomSheetTitle: "Maximum File Size",
                        searchBackgroundColor: Colors.black12,
                        dataList: [
                          SelectedListItem(store.state.preferencesState.maximumAutoDownloadSize == 1, "1MB"),
                          SelectedListItem(store.state.preferencesState.maximumAutoDownloadSize == 5, "5MB"),
                          SelectedListItem(store.state.preferencesState.maximumAutoDownloadSize == 15, "15MB"),
                          SelectedListItem(store.state.preferencesState.maximumAutoDownloadSize == 100, "100MB"),
                          SelectedListItem(store.state.preferencesState.maximumAutoDownloadSize == -1, "Always")
                        ],
                        selectedItem: (String selected) {
                          int value = -1;
                          switch (selected) {
                            case "1MB": {
                              value = 1;
                            }
                            break;
                            case "5MB": {
                              value = 5;
                            }
                            break;
                            case "15MB": {
                              value = 15;
                            }
                            break;
                            case "100MB": {
                              value = 100;
                            }
                            break;
                            default: {
                              value = -1;
                            }
                            break;
                          }

                          store.dispatch(
                            SetPreferencesAction(
                              store.state.preferencesState.copyWith(
                                maximumAutoDownloadSize: value
                              )
                            )
                          );
                        },
                        enableMultipleSelection: false,
                        searchController: TextEditingController()
                      ),
                    ).showModal(context);
                  }
                ),
              ]
            )
          ]
        )
      )
    );
  }
}