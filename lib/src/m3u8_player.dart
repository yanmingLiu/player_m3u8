import 'package:flutter/widgets.dart';

import 'm3u8_player_controller.dart';
import 'm3u8_player_value.dart';

class M3u8Player extends StatelessWidget {
  const M3u8Player({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.backgroundColor = const Color(0xFF000000),
  });

  final M3u8PlayerController controller;
  final BoxFit fit;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<M3u8PlayerValue>(
      valueListenable: controller,
      builder: (BuildContext context, M3u8PlayerValue value, Widget? child) {
        final playerId = controller.playerId;
        if (!value.isInitialized || playerId == null) {
          return ColoredBox(color: backgroundColor);
        }

        final texture = Texture(textureId: playerId);
        final sizedTexture = SizedBox(
          width: value.size.width,
          height: value.size.height,
          child: texture,
        );

        return ColoredBox(
          color: backgroundColor,
          child: FittedBox(
            fit: fit,
            clipBehavior: Clip.hardEdge,
            child: sizedTexture,
          ),
        );
      },
    );
  }
}
