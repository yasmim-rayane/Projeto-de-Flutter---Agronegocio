import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/alerta.dart';
import '../models/propriedade.dart';
import '../models/registro_campo.dart';
import '../models/talhao.dart';
import '../models/usuario.dart';
import 'id_generator.dart';
import 'permission_service.dart';

/// Conjunto completo de dados carregados para o painel agrícola.
class AgroSnapshot {
  const AgroSnapshot({
    required this.propriedades,
    required this.talhoes,
    required this.registros,
    required this.alertas,
  });

  final List<Propriedade> propriedades;
  final List<Talhao> talhoes;
  final List<RegistroCampo> registros;
  final List<Alerta> alertas;
}

/// Exceção amigável para falhas de autenticação ou persistência.
class RepositoryException implements Exception {
  RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Indica que a conta foi criada com sucesso e aguarda confirmação de e-mail.
class EmailConfirmationRequiredException extends RepositoryException {
  EmailConfirmationRequiredException(super.message);
}

/// Contrato único para persistência remota (Supabase) ou fallback local persistido.
abstract class AgroRepository {
  bool get isRemote;

  Future<AppUser?> restoreSession();

  Future<AppUser> login({
    required String email,
    required String senha,
  });

  Future<AppUser> register({
    required String nome,
    required String email,
    required String senha,
    required UserRole perfil,
  });

  Future<void> logout();

  Future<AgroSnapshot> loadAll(AppUser user);

  Future<Propriedade> savePropriedade({
    required AppUser user,
    required Propriedade propriedade,
    required bool isUpdate,
  });

  Future<Talhao> saveTalhao({
    required AppUser user,
    required Talhao talhao,
    required bool isUpdate,
  });

  Future<void> registrarEventoCampo({
    required AppUser user,
    required Talhao talhaoAtualizado,
    required RegistroCampo registro,
    required List<Alerta> novosAlertas,
    required List<String> alertasResolvidosIds,
  });

  Future<void> sincronizarAlertas({
    required List<Alerta> novosAlertas,
    required List<String> alertasResolvidosIds,
  });

  Future<void> resolverAlerta({
    required AppUser user,
    required String alertaId,
  });
}

/// Implementação conectada ao Supabase (Auth + PostgREST com RLS ativo).
class SupabaseAgroRepository implements AgroRepository {
  SupabaseAgroRepository({
    required this.baseUrl,
    required this.anonKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String anonKey;
  final http.Client _client;

  static const String _sessionKey = 'agro_supabase_session_v1';
  String? _accessToken;
  AppUser? _currentUser;

  @override
  bool get isRemote => true;

  String get _cleanBaseUrl =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  Map<String, String> _headers({bool includeAuth = true}) {
    return {
      'apikey': anonKey,
      'Content-Type': 'application/json',
      if (includeAuth && _accessToken != null)
        'Authorization': 'Bearer $_accessToken',
    };
  }

  @override
  Future<AppUser?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _accessToken = decoded['access_token']?.toString();
      final userMap = decoded['user'] as Map<String, dynamic>?;
      if (_accessToken == null || userMap == null) return null;

      // Valida sessão ativa junto ao endpoint /auth/v1/user.
      final res = await _client.get(
        Uri.parse('$_cleanBaseUrl/auth/v1/user'),
        headers: _headers(),
      );
      if (res.statusCode != 200) {
        await logout();
        return null;
      }
      _currentUser = AppUser.fromMap(userMap);
      return _currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> login({
    required String email,
    required String senha,
  }) async {
    final uri = Uri.parse('$_cleanBaseUrl/auth/v1/token?grant_type=password');
    final response = await _client.post(
      uri,
      headers: _headers(includeAuth: false),
      body: jsonEncode({
        'email': email.trim(),
        'password': senha,
      }),
    );

    if (response.statusCode != 200) {
      throw RepositoryException(_extractSupabaseError(response.body,
          fallback: 'E-mail ou senha inválidos.'));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = data['access_token']?.toString();
    final authUser = data['user'] as Map<String, dynamic>?;
    final userId = authUser?['id']?.toString() ?? '';

    final perfil = await _fetchOrCreatePerfil(
      userId: userId,
      email: email.trim(),
      metadata: authUser?['user_metadata'] as Map<String, dynamic>?,
    );

    _currentUser = perfil;
    await _persistSession(perfil);
    return perfil;
  }

  @override
  Future<AppUser> register({
    required String nome,
    required String email,
    required String senha,
    required UserRole perfil,
  }) async {
    final uri = Uri.parse('$_cleanBaseUrl/auth/v1/signup');
    final response = await _client.post(
      uri,
      headers: _headers(includeAuth: false),
      body: jsonEncode({
        'email': email.trim(),
        'password': senha,
        'data': {
          'nome': nome.trim(),
          'perfil': perfil.apiValue,
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RepositoryException(_extractSupabaseError(response.body,
          fallback: 'Não foi possível concluir o cadastro.'));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token']?.toString();
    final userObj = (data['user'] as Map<String, dynamic>?) ?? data;
    final userId = userObj['id']?.toString() ?? '';

    if (token == null || token.isEmpty) {
      throw EmailConfirmationRequiredException(
        'Conta cadastrada com sucesso! Confirme seu e-mail para entrar no sistema.',
      );
    }

    _accessToken = token;
    final appUser = AppUser(
      id: userId,
      nome: nome.trim(),
      email: email.trim(),
      perfil: perfil,
    );

    await _upsertPerfil(appUser);
    _currentUser = appUser;
    await _persistSession(appUser);
    return appUser;
  }

  Future<AppUser> _fetchOrCreatePerfil({
    required String userId,
    required String email,
    Map<String, dynamic>? metadata,
  }) async {
    final uri = Uri.parse(
      '$_cleanBaseUrl/rest/v1/perfis?id=eq.$userId&select=*',
    );
    final res = await _client.get(uri, headers: _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isNotEmpty) {
        return AppUser.fromMap(list.first as Map<String, dynamic>);
      }
    }

    final fallbackUser = AppUser(
      id: userId,
      nome: metadata?['nome']?.toString() ?? email.split('@').first,
      email: email,
      perfil: UserRole.fromApiValue(metadata?['perfil']?.toString()),
    );
    await _upsertPerfil(fallbackUser);
    return fallbackUser;
  }

  Future<void> _upsertPerfil(AppUser user) async {
    final uri = Uri.parse('$_cleanBaseUrl/rest/v1/perfis');
    final res = await _client.post(
      uri,
      headers: {
        ..._headers(),
        'Prefer': 'resolution=merge-duplicates',
      },
      body: jsonEncode(user.toMap()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw RepositoryException(
        _extractSupabaseError(res.body, fallback: 'Erro ao salvar perfil.'),
      );
    }
  }

  Future<void> _persistSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionKey,
      jsonEncode({
        'access_token': _accessToken,
        'user': user.toMap(),
      }),
    );
  }

  @override
  Future<void> logout() async {
    _accessToken = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  @override
  Future<AgroSnapshot> loadAll(AppUser user) async {
    PermissionService.ensureAllowed(user.perfil, PermissionAction.consultarDados);

    final propsFuture = _getList('propriedades?order=criado_em.desc');
    final talhoesFuture = _getList('talhoes?order=ultima_atualizacao.desc');
    final regFuture = _getList('registros_campo?order=criado_em.desc');
    final alertasFuture = _getList('alertas?order=criado_em.desc');

    final results = await Future.wait([
      propsFuture,
      talhoesFuture,
      regFuture,
      alertasFuture,
    ]);

    return AgroSnapshot(
      propriedades: results[0].map(Propriedade.fromMap).toList(),
      talhoes: results[1].map(Talhao.fromMap).toList(),
      registros: results[2].map(RegistroCampo.fromMap).toList(),
      alertas: results[3].map(Alerta.fromMap).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final res = await _client.get(
      Uri.parse('$_cleanBaseUrl/rest/v1/$path'),
      headers: _headers(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw RepositoryException(
        _extractSupabaseError(res.body, fallback: 'Erro ao carregar dados.'),
      );
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  @override
  Future<Propriedade> savePropriedade({
    required AppUser user,
    required Propriedade propriedade,
    required bool isUpdate,
  }) async {
    PermissionService.ensureAllowed(
      user.perfil,
      PermissionAction.cadastrarPropriedade,
    );

    if (isUpdate) {
      final res = await _client.patch(
        Uri.parse('$_cleanBaseUrl/rest/v1/propriedades?id=eq.${propriedade.id}'),
        headers: {
          ..._headers(),
          'Prefer': 'return=representation',
        },
        body: jsonEncode(propriedade.toMap()),
      );
      _ensureSuccess(res, 'Erro ao atualizar propriedade.');
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.isNotEmpty
          ? Propriedade.fromMap(list.first as Map<String, dynamic>)
          : propriedade;
    }

    final res = await _client.post(
      Uri.parse('$_cleanBaseUrl/rest/v1/propriedades'),
      headers: {
        ..._headers(),
        'Prefer': 'return=representation',
      },
      body: jsonEncode(propriedade.toMap()),
    );
    _ensureSuccess(res, 'Erro ao cadastrar propriedade.');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.isNotEmpty
        ? Propriedade.fromMap(list.first as Map<String, dynamic>)
        : propriedade;
  }

  @override
  Future<Talhao> saveTalhao({
    required AppUser user,
    required Talhao talhao,
    required bool isUpdate,
  }) async {
    PermissionService.ensureAllowed(
      user.perfil,
      isUpdate
          ? PermissionAction.editarPlantioTalhao
          : PermissionAction.cadastrarTalhao,
    );

    if (isUpdate) {
      final res = await _client.patch(
        Uri.parse('$_cleanBaseUrl/rest/v1/talhoes?id=eq.${talhao.id}'),
        headers: {
          ..._headers(),
          'Prefer': 'return=representation',
        },
        body: jsonEncode(talhao.toMap()),
      );
      _ensureSuccess(res, 'Erro ao atualizar talhão.');
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.isNotEmpty
          ? Talhao.fromMap(list.first as Map<String, dynamic>)
          : talhao;
    }

    final res = await _client.post(
      Uri.parse('$_cleanBaseUrl/rest/v1/talhoes'),
      headers: {
        ..._headers(),
        'Prefer': 'return=representation',
      },
      body: jsonEncode(talhao.toMap()),
    );
    _ensureSuccess(res, 'Erro ao cadastrar talhão.');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.isNotEmpty
        ? Talhao.fromMap(list.first as Map<String, dynamic>)
        : talhao;
  }

  @override
  Future<void> registrarEventoCampo({
    required AppUser user,
    required Talhao talhaoAtualizado,
    required RegistroCampo registro,
    required List<Alerta> novosAlertas,
    required List<String> alertasResolvidosIds,
  }) async {
    final requiredAction = switch (registro.tipo) {
      TipoRegistroCampo.plantio => PermissionAction.editarPlantioTalhao,
      TipoRegistroCampo.condicao => PermissionAction.atualizarCondicaoTalhao,
      TipoRegistroCampo.ocorrencia => PermissionAction.registrarOcorrencia,
    };
    PermissionService.ensureAllowed(user.perfil, requiredAction);

    // 1. Atualiza estado do talhão
    final talhaoRes = await _client.patch(
      Uri.parse('$_cleanBaseUrl/rest/v1/talhoes?id=eq.${talhaoAtualizado.id}'),
      headers: _headers(),
      body: jsonEncode(talhaoAtualizado.toMap()),
    );
    _ensureSuccess(talhaoRes, 'Erro ao atualizar estado do talhão.');

    // 2. Insere registro no histórico
    final regRes = await _client.post(
      Uri.parse('$_cleanBaseUrl/rest/v1/registros_campo'),
      headers: _headers(),
      body: jsonEncode(registro.toMap(autorId: user.id)),
    );
    _ensureSuccess(regRes, 'Erro ao gravar histórico de campo.');

    // 3. Sincroniza alertas gerados/sanados automaticamente
    await sincronizarAlertas(
      novosAlertas: novosAlertas,
      alertasResolvidosIds: alertasResolvidosIds,
    );
  }

  @override
  Future<void> sincronizarAlertas({
    required List<Alerta> novosAlertas,
    required List<String> alertasResolvidosIds,
  }) async {
    if (novosAlertas.isNotEmpty) {
      final res = await _client.post(
        Uri.parse('$_cleanBaseUrl/rest/v1/alertas'),
        headers: _headers(),
        body: jsonEncode(novosAlertas.map((a) => a.toMap()).toList()),
      );
      _ensureSuccess(res, 'Erro ao gravar novos alertas.');
    }

    for (final alertaId in alertasResolvidosIds) {
      final res = await _client.patch(
        Uri.parse('$_cleanBaseUrl/rest/v1/alertas?id=eq.$alertaId'),
        headers: _headers(),
        body: jsonEncode({
          'ativo': false,
          'resolvido_em': DateTime.now().toUtc().toIso8601String(),
          'resolvido_por': 'Sistema (condição normalizada)',
        }),
      );
      _ensureSuccess(res, 'Erro ao atualizar alerta normalizado.');
    }
  }

  @override
  Future<void> resolverAlerta({
    required AppUser user,
    required String alertaId,
  }) async {
    PermissionService.ensureAllowed(user.perfil, PermissionAction.resolverAlerta);
    final res = await _client.patch(
      Uri.parse('$_cleanBaseUrl/rest/v1/alertas?id=eq.$alertaId'),
      headers: _headers(),
      body: jsonEncode({
        'ativo': false,
        'resolvido_em': DateTime.now().toUtc().toIso8601String(),
        'resolvido_por': '${user.nome} (${user.perfil.label})',
      }),
    );
    _ensureSuccess(res, 'Sem permissão ou falha ao resolver alerta.');
  }

  void _ensureSuccess(http.Response res, String fallback) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw RepositoryException(_extractSupabaseError(res.body, fallback: fallback));
    }
  }

  String _extractSupabaseError(String body, {required String fallback}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['msg']?.toString() ??
            decoded['message']?.toString() ??
            decoded['error_description']?.toString() ??
            fallback;
      }
    } catch (_) {}
    return fallback;
  }
}

/// Implementação local persistida (SharedPreferences) utilizada apenas quando
/// credenciais do Supabase não estão configuradas em tempo de execução.
class LocalAgroRepository implements AgroRepository {
  LocalAgroRepository();

  static const String _storageKey = 'agro_campo_local_db_v1';
  static const String _currentUserKey = 'agro_campo_local_session_v1';

  @override
  bool get isRemote => false;

  Future<Map<String, dynamic>> _loadDb() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    final seeded = _createInitialSeedData();
    await prefs.setString(_storageKey, jsonEncode(seeded));
    return seeded;
  }

  Future<void> _saveDb(Map<String, dynamic> db) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(db));
  }

  @override
  Future<AppUser?> restoreSession() async {
    await _loadDb();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentUserKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppUser.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser> login({
    required String email,
    required String senha,
  }) async {
    final db = await _loadDb();
    final users = (db['users'] as List<dynamic>).cast<Map<String, dynamic>>();
    final emailLower = email.trim().toLowerCase();

    final match = users.cast<Map<String, dynamic>?>().firstWhere(
          (u) =>
              u!['email'].toString().toLowerCase() == emailLower &&
              u['senha'].toString() == senha,
          orElse: () => null,
        );

    if (match == null) {
      throw RepositoryException('E-mail ou senha incorretos.');
    }

    final user = AppUser.fromMap(match);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, jsonEncode(user.toMap()));
    return user;
  }

  @override
  Future<AppUser> register({
    required String nome,
    required String email,
    required String senha,
    required UserRole perfil,
  }) async {
    final db = await _loadDb();
    final users = (db['users'] as List<dynamic>).cast<Map<String, dynamic>>();
    final emailLower = email.trim().toLowerCase();

    final exists = users.any(
      (u) => u['email'].toString().toLowerCase() == emailLower,
    );
    if (exists) {
      throw RepositoryException('Já existe uma conta cadastrada com este e-mail.');
    }

    final newUser = AppUser(
      id: IdGenerator.uuidV4(),
      nome: nome.trim(),
      email: emailLower,
      perfil: perfil,
    );

    users.add({
      ...newUser.toMap(),
      'senha': senha,
    });
    await _saveDb(db);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, jsonEncode(newUser.toMap()));
    return newUser;
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  @override
  Future<AgroSnapshot> loadAll(AppUser user) async {
    PermissionService.ensureAllowed(user.perfil, PermissionAction.consultarDados);
    final db = await _loadDb();

    final propriedades = (db['propriedades'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Propriedade.fromMap)
        .toList()
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

    final talhoes = (db['talhoes'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Talhao.fromMap)
        .toList()
      ..sort((a, b) => b.ultimaAtualizacao.compareTo(a.ultimaAtualizacao));

    final registros = (db['registros'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(RegistroCampo.fromMap)
        .toList()
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

    final alertas = (db['alertas'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Alerta.fromMap)
        .toList()
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

    return AgroSnapshot(
      propriedades: propriedades,
      talhoes: talhoes,
      registros: registros,
      alertas: alertas,
    );
  }

  @override
  Future<Propriedade> savePropriedade({
    required AppUser user,
    required Propriedade propriedade,
    required bool isUpdate,
  }) async {
    PermissionService.ensureAllowed(
      user.perfil,
      PermissionAction.cadastrarPropriedade,
    );

    final db = await _loadDb();
    final list =
        (db['propriedades'] as List<dynamic>).cast<Map<String, dynamic>>();

    if (isUpdate) {
      final index = list.indexWhere((p) => p['id'] == propriedade.id);
      if (index >= 0) {
        list[index] = propriedade.toMap();
      } else {
        list.add(propriedade.toMap());
      }
    } else {
      list.add(propriedade.toMap());
    }

    await _saveDb(db);
    return propriedade;
  }

  @override
  Future<Talhao> saveTalhao({
    required AppUser user,
    required Talhao talhao,
    required bool isUpdate,
  }) async {
    PermissionService.ensureAllowed(
      user.perfil,
      isUpdate
          ? PermissionAction.editarPlantioTalhao
          : PermissionAction.cadastrarTalhao,
    );

    final db = await _loadDb();
    final list = (db['talhoes'] as List<dynamic>).cast<Map<String, dynamic>>();
    if (isUpdate) {
      final index = list.indexWhere((t) => t['id'] == talhao.id);
      if (index >= 0) {
        list[index] = talhao.toMap();
      } else {
        list.add(talhao.toMap());
      }
    } else {
      list.add(talhao.toMap());
    }
    await _saveDb(db);
    return talhao;
  }

  @override
  Future<void> registrarEventoCampo({
    required AppUser user,
    required Talhao talhaoAtualizado,
    required RegistroCampo registro,
    required List<Alerta> novosAlertas,
    required List<String> alertasResolvidosIds,
  }) async {
    final requiredAction = switch (registro.tipo) {
      TipoRegistroCampo.plantio => PermissionAction.editarPlantioTalhao,
      TipoRegistroCampo.condicao => PermissionAction.atualizarCondicaoTalhao,
      TipoRegistroCampo.ocorrencia => PermissionAction.registrarOcorrencia,
    };
    PermissionService.ensureAllowed(user.perfil, requiredAction);

    final db = await _loadDb();
    final talhoes =
        (db['talhoes'] as List<dynamic>).cast<Map<String, dynamic>>();
    final tIndex = talhoes.indexWhere((t) => t['id'] == talhaoAtualizado.id);
    if (tIndex >= 0) {
      talhoes[tIndex] = talhaoAtualizado.toMap();
    }

    final registros =
        (db['registros'] as List<dynamic>).cast<Map<String, dynamic>>();
    registros.add(registro.toMap(autorId: user.id));

    await _applyAlertChanges(db, novosAlertas, alertasResolvidosIds);
    await _saveDb(db);
  }

  @override
  Future<void> sincronizarAlertas({
    required List<Alerta> novosAlertas,
    required List<String> alertasResolvidosIds,
  }) async {
    if (novosAlertas.isEmpty && alertasResolvidosIds.isEmpty) return;
    final db = await _loadDb();
    await _applyAlertChanges(db, novosAlertas, alertasResolvidosIds);
    await _saveDb(db);
  }

  Future<void> _applyAlertChanges(
    Map<String, dynamic> db,
    List<Alerta> novosAlertas,
    List<String> alertasResolvidosIds,
  ) async {
    final alertas =
        (db['alertas'] as List<dynamic>).cast<Map<String, dynamic>>();
    for (final novo in novosAlertas) {
      alertas.add(novo.toMap());
    }
    for (final id in alertasResolvidosIds) {
      final index = alertas.indexWhere((a) => a['id'] == id);
      if (index >= 0) {
        alertas[index]['ativo'] = false;
        alertas[index]['resolvido_em'] = DateTime.now().toUtc().toIso8601String();
        alertas[index]['resolvido_por'] = 'Sistema (condição normalizada)';
      }
    }
  }

  @override
  Future<void> resolverAlerta({
    required AppUser user,
    required String alertaId,
  }) async {
    PermissionService.ensureAllowed(user.perfil, PermissionAction.resolverAlerta);
    final db = await _loadDb();
    final alertas =
        (db['alertas'] as List<dynamic>).cast<Map<String, dynamic>>();
    final index = alertas.indexWhere((a) => a['id'] == alertaId);
    if (index >= 0) {
      alertas[index]['ativo'] = false;
      alertas[index]['resolvido_em'] = DateTime.now().toUtc().toIso8601String();
      alertas[index]['resolvido_por'] = '${user.nome} (${user.perfil.label})';
      await _saveDb(db);
    }
  }

  /// Cria contas de demonstração para os 4 perfis e 1 cenário inicial coerente
  /// para facilitar testes de campo logo após abrir o aplicativo.
  Map<String, dynamic> _createInitialSeedData() {
    final agora = DateTime.now();
    const gestorId = '11111111-1111-4111-8111-111111111111';
    const propId = '22222222-2222-4222-8222-222222222222';
    const talhao1Id = '33333333-3333-4333-8333-333333333331';
    const talhao2Id = '33333333-3333-4333-8333-333333333332';

    final plantioT1 = agora.subtract(const Duration(days: 92));
    final colheitaT1 = agora.add(const Duration(days: 4));
    final plantioT2 = agora.subtract(const Duration(days: 40));
    final colheitaT2 = agora.add(const Duration(days: 65));

    return {
      'users': [
        {
          'id': gestorId,
          'nome': 'Helena Gestora',
          'email': 'gestor@agrocampo.app',
          'senha': '123456',
          'perfil': UserRole.gestorPropriedade.apiValue,
        },
        {
          'id': '11111111-1111-4111-8111-111111111112',
          'nome': 'Carlos Produtor',
          'email': 'produtor@agrocampo.app',
          'senha': '123456',
          'perfil': UserRole.produtorRural.apiValue,
        },
        {
          'id': '11111111-1111-4111-8111-111111111113',
          'nome': 'Mariana Agrônoma',
          'email': 'agronomo@agrocampo.app',
          'senha': '123456',
          'perfil': UserRole.agronomo.apiValue,
        },
        {
          'id': '11111111-1111-4111-8111-111111111114',
          'nome': 'Lucas Técnico',
          'email': 'tecnico@agrocampo.app',
          'senha': '123456',
          'perfil': UserRole.tecnicoAgricola.apiValue,
        },
      ],
      'propriedades': [
        Propriedade(
          id: propId,
          nome: 'Fazenda Santa Helena (Demo)',
          municipio: 'Ribeirão Preto',
          estado: 'SP',
          areaTotalHa: 180.0,
          latitude: -21.1775,
          longitude: -47.8103,
          criadoPor: gestorId,
          criadoEm: plantioT1,
        ).toMap(),
      ],
      'talhoes': [
        Talhao(
          id: talhao1Id,
          propriedadeId: propId,
          identificacao: 'Talhão A1 - Norte',
          cultura: 'Soja',
          areaHa: 45.0,
          dataPlantio: plantioT1,
          previsaoColheita: colheitaT1,
          umidade: 48.0,
          situacao: SituacaoTalhao.atencao,
          observacoes: 'Maturação avançada; monitorar janela de colheita.',
          ultimaAtualizacao: agora.subtract(const Duration(hours: 6)),
          criadoPor: gestorId,
        ).toMap(),
        Talhao(
          id: talhao2Id,
          propriedadeId: propId,
          identificacao: 'Talhão B2 - Várzea',
          cultura: 'Milho',
          areaHa: 32.5,
          dataPlantio: plantioT2,
          previsaoColheita: colheitaT2,
          umidade: 28.0,
          situacao: SituacaoTalhao.critico,
          observacoes: 'Solo seco após estiagem; avaliar irrigação imediata.',
          ultimaAtualizacao: agora.subtract(const Duration(hours: 2)),
          criadoPor: gestorId,
        ).toMap(),
      ],
      'registros': [
        RegistroCampo(
          id: '44444444-4444-4444-8444-444444444441',
          talhaoId: talhao1Id,
          propriedadeId: propId,
          tipo: TipoRegistroCampo.plantio,
          titulo: 'Plantio inicial de Soja',
          descricao: 'Semeadura direta concluída em 45 ha.',
          umidadeRegistrada: 56.0,
          situacaoRegistrada: SituacaoTalhao.saudavel,
          autorNome: 'Helena Gestora',
          autorPerfil: UserRole.gestorPropriedade,
          criadoEm: plantioT1,
        ).toMap(autorId: gestorId),
        RegistroCampo(
          id: '44444444-4444-4444-8444-444444444442',
          talhaoId: talhao2Id,
          propriedadeId: propId,
          tipo: TipoRegistroCampo.condicao,
          titulo: 'Leitura de umidade em campo',
          descricao: 'Umidade do solo caiu para 28%.',
          umidadeRegistrada: 28.0,
          situacaoRegistrada: SituacaoTalhao.critico,
          autorNome: 'Lucas Técnico',
          autorPerfil: UserRole.tecnicoAgricola,
          criadoEm: agora.subtract(const Duration(hours: 2)),
        ).toMap(),
      ],
      'alertas': [
        Alerta(
          id: '55555555-5555-4555-8555-555555555551',
          talhaoId: talhao1Id,
          propriedadeId: propId,
          regra: RegraAlerta.proximidadeColheita,
          severidade: Severidade.media,
          titulo: 'Colheita próxima em Talhão A1 - Norte',
          mensagem: 'Faltam 4 dia(s) para a colheita prevista de Soja.',
          parametroDisparo: 'Prazo restante: 4 dia(s) (janela <= 7 dias)',
          ativo: true,
          criadoEm: agora.subtract(const Duration(hours: 6)),
        ).toMap(),
        Alerta(
          id: '55555555-5555-4555-8555-555555555552',
          talhaoId: talhao2Id,
          propriedadeId: propId,
          regra: RegraAlerta.umidadeBaixa,
          severidade: Severidade.media,
          titulo: 'Umidade baixa em Talhão B2 - Várzea',
          mensagem:
              'A cultura Milho atingiu 28.0% de umidade, abaixo do mínimo operacional de 35%. Avaliar irrigação.',
          parametroDisparo: 'Umidade atual: 28.0% (< 35%)',
          ativo: true,
          criadoEm: agora.subtract(const Duration(hours: 2)),
        ).toMap(),
      ],
    };
  }
}

/// Fábrica simples para instanciar o repositório configurado no ambiente.
AgroRepository createDefaultRepository() {
  if (AppConfig.hasSupabaseConfig) {
    return SupabaseAgroRepository(
      baseUrl: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }
  return LocalAgroRepository();
}

