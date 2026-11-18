/// Configurações de integração externa carregadas em tempo de compilação.
///
/// Nenhuma chave administrativa é embutida no código-fonte.
class AppConfig {
  /// URL do projeto Supabase informada via `--dart-define=SUPABASE_URL=...`.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Chave pública (anon key) do Supabase informada via
  /// `--dart-define=SUPABASE_ANON_KEY=...`.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Indica se a persistência remota Supabase está configurada.
  static bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}

