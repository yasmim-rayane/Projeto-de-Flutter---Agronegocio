import 'package:material_ui/material_ui.dart';

import '../models/registro_campo.dart';
import '../models/talhao.dart';

/// Paleta e tema projetados para legibilidade em campo (alto contraste e toques amplos).
class AgroTheme {
  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color secondaryGreen = Color(0xFF2E7D32);
  static const Color earthAccent = Color(0xFF8D6E63);
  static const Color surfaceBackground = Color(0xFFF4F6F3);

  static ThemeData buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: secondaryGreen,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 1,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static Color corSituacao(SituacaoTalhao situacao) {
    return switch (situacao) {
      SituacaoTalhao.saudavel => const Color(0xFF2E7D32),
      SituacaoTalhao.atencao => const Color(0xFFEF6C00),
      SituacaoTalhao.critico => const Color(0xFFC62828),
      SituacaoTalhao.colhido => const Color(0xFF455A64),
    };
  }

  static Color corSeveridade(Severidade severidade) {
    return switch (severidade) {
      Severidade.baixa => const Color(0xFF2E7D32),
      Severidade.media => const Color(0xFFEF6C00),
      Severidade.alta => const Color(0xFFC62828),
    };
  }
}
