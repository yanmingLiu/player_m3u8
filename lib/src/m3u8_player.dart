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
        if (playerId == null) {
          return ColoredBox(color: backgroundColor);
        }

        final texture = Texture(textureId: playerId);
        final textureSize = value.size.width > 0 && value.size.height > 0
            ? value.size
            : const Size(16, 9);
        final sizedTexture = SizedBox(
          width: textureSize.width,
          height: textureSize.height,
          child: texture,
        );

        return ColoredBox(
          color: backgroundColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: fit,
                clipBehavior: Clip.hardEdge,
                child: sizedTexture,
              ),
              if (value.subtitleText.isNotEmpty)
                PositionedDirectional(
                  start: 16,
                  end: 16,
                  bottom: 20,
                  child: IgnorePointer(
                    child: Text(
                      value.subtitleText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        shadows: <Shadow>[
                          Shadow(
                            color: Color(0xE6000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
