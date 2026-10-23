import 'package:flutter/material.dart';

/// Logotipo do LEGIS.
/// - `compact`: wordmark horizontal. Por padrão usa a versão clara (off-white),
///   própria para AppBar e menu lateral azul-noturno. Use `onLight: true` em
///   fundos claros.
/// - sem `compact`: logomarca completa (balança e martelo), que já traz o fundo
///   azul-noturno da identidade visual.
class LegisLogo extends StatelessWidget {
  const LegisLogo({super.key, this.compact = false, this.onLight = false, this.size = 220});

  final bool compact;
  final bool onLight;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Semantics(
        label: 'LEGIS — acompanhamento legislativo',
        image: true,
        child: Image.asset(
          onLight ? 'assets/images/legis_wordmark.png' : 'assets/images/legis_wordmark_light.png',
          width: 116,
          height: 43,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      );
    }
    return ClipRRect(
      // Mantém os cantos arredondados mesmo se o arquivo do logotipo for trocado.
      borderRadius: BorderRadius.circular(size * 0.085),
      child: Image.asset(
        'assets/images/legis_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Logomarca LEGIS com balança da justiça e martelo',
      ),
    );
  }
}
