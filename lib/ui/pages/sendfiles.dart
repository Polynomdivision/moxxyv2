import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moxxyv2/ui/bloc/sendfiles_bloc.dart';
import 'package:moxxyv2/ui/constants.dart';
import 'package:moxxyv2/ui/widgets/chat/shared/base.dart';
import 'package:moxxyv2/ui/widgets/chat/shared/image.dart';
import 'package:moxxyv2/ui/widgets/chat/thumbnail.dart';

class SendFilesPage extends StatelessWidget {
 
  const SendFilesPage({ Key? key }) : super(key: key);

  static MaterialPageRoute get route => MaterialPageRoute<dynamic>(builder: (context) => const SendFilesPage());
  
  void _sendFiles(BuildContext context) {
    // TODO(PapaTutuWawa): Stubbed
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // TODO(Unknown): Fix the typography
    return SafeArea(
      child: Scaffold(
        // appBar: BorderlessTopbar.justBackButton(),
        body: BlocBuilder<SendFilesBloc, SendFilesState>(
          builder: (context, state) => Stack(
            children: [
              const Positioned(
                top: 0,
                left: 0,
                child: BackButton(),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ImageThumbnailWidget(
                        state.files[state.index],
                        Image.memory,
                      ),
                    ],
                  ),
                ),
              ),
              // TODO(Unknown): Add a TextField for entering a message
              Positioned(
                left: 0,
                right: 0,
                bottom: 72,
                child: SizedBox(
                  height: 96,
                  child: Container(
                    color: const Color.fromRGBO(0, 0, 0, 0.7),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.files.length + 1,
                        itemBuilder: (context, index) {
                          if (index < state.files.length) {
                            final item = state.files[index];

                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: SharedImageWidget(
                                item,
                                () => context.read<SendFilesBloc>().add(
                                  IndexSetEvent(index),
                                ),
                                borderColor: index == state.index ? Colors.blue : null,
                              ),
                            );
                          } else {
                            return SharedMediaContainer(
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.grey,
                                ),
                                child: const Icon(Icons.attach_file),
                              ),
                              onTap: () => context.read<SendFilesBloc>().add(AddFilesRequestedEvent()),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: SizedBox(
                  height: 48,
                  width: 48,
                  child: FittedBox(
                    // Without wrapping the button in a Material, the image will be drawn
                    // over the button, partly or entirely hiding it.
                    child: Material(
                      color: Color.fromRGBO(0, 0, 0, 0),
                      child: Ink(
                        decoration: const ShapeDecoration(
                          color: primaryColor,
                          shape: CircleBorder(),
                        ),
                        child: IconButton(
                          color: Colors.white,
                          icon: const Icon(Icons.send),
                          onPressed: () => context.read<SendFilesBloc>().add(FileSendingRequestedEvent()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
