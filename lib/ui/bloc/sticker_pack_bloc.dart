import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:get_it/get_it.dart';
import 'package:moxlib/moxlib.dart';
import 'package:moxxyv2/shared/models/sticker_pack.dart';
import 'package:moxxyv2/ui/bloc/navigation_bloc.dart';
import 'package:moxxyv2/ui/bloc/stickers_bloc.dart';
import 'package:moxxyv2/ui/constants.dart';

part 'sticker_pack_bloc.freezed.dart';
part 'sticker_pack_event.dart';
part 'sticker_pack_state.dart';

class StickerPackBloc extends Bloc<StickerPackEvent, StickerPackState> {
  StickerPackBloc() : super(StickerPackState()) {
    on<LocallyAvailableStickerPackRequested>(_onLocalStickerPackRequested);
  }

  Future<void> _onLocalStickerPackRequested(LocallyAvailableStickerPackRequested event, Emitter<StickerPackState> emit) async {
    final mustDoWork = state.stickerPack == null || state.stickerPack?.id != event.stickerPackId;
    if (mustDoWork) {
      emit(
        state.copyWith(
          isWorking: true,
        ),
      );
    }

    // Navigate
    GetIt.I.get<NavigationBloc>().add(
      PushedNamedEvent(
        const NavigationDestination(stickerPackRoute),
      ),
    );

    if (mustDoWork) {
      // Apply
      final stickerPack = firstWhereOrNull(
        GetIt.I.get<StickersBloc>().state.stickerPacks,
        (StickerPack pack) => pack.id == event.stickerPackId,
      );
      assert(stickerPack != null, 'The sticker pack must be found');
      emit(
        state.copyWith(
          isWorking: false,
          stickerPack: stickerPack,
        ),
      );
    }
  }
}
