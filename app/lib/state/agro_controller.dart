import 'package:flutter/foundation.dart';

import '../models/alerta.dart';
import '../models/clima_info.dart';
import '../models/propriedade.dart';
import '../models/registro_campo.dart';
import '../models/talhao.dart';
import '../models/usuario.dart';
import '../services/agro_repository.dart';
import '../services/alert_engine.dart';
import '../services/id_generator.dart';
import '../services/permission_service.dart';
import '../services/weather_api_service.dart';

/// Opções de ordenação da listagem de talhões.
enum TalhaoOrdenacao {
  ultimaAtualizacao('Mais recentes'),
  colheitaProxima('Colheita mais próxima'),
  umidadeCrescente('Menor umidade'),
  identificacaoAz('Identificação (A-Z)');

  const TalhaoOrdenacao(this.label);

  final String label;
}

/// Gerenciador de estado central do aplicativo AgroCampo.
class AgroController extends ChangeNotifier {
  AgroController({
    required this._repository,
    required this._weatherService,
  });

  final AgroRepository _repository;
  final WeatherApiService _weatherService;

  AppUser? _currentUser;
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<Propriedade> _propriedades = [];
  List<Talhao> _talhoes = [];
  List<RegistroCampo> _registros = [];
  List<Alerta> _alertas = [];

  final Map<String, ClimaInfo> _climaPorPropriedade = {};
  final Map<String, String> _climaErroPorPropriedade = {};
  final Set<String> _carregandoClima = {};

  AppUser? get currentUser => _currentUser;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get isRemoteMode => _repository.isRemote;

  List<Propriedade> get propriedades => List.unmodifiable(_propriedades);
  List<Talhao> get talhoes => List.unmodifiable(_talhoes);
  List<RegistroCampo> get registros => List.unmodifiable(_registros);
  List<Alerta> get alertas => List.unmodifiable(_alertas);

  List<Alerta> get alertasAtivos =>
      _alertas.where((a) => a.ativo).toList(growable: false);

  List<Alerta> get alertasResolvidos =>
      _alertas.where((a) => !a.ativo).toList(growable: false);

  List<String> get culturasDisponiveis {
    final set = _talhoes
        .map((t) => t.cultura.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    set.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return set;
  }

  bool can(PermissionAction action) {
    final user = _currentUser;
    if (user == null) return false;
    return PermissionService.can(user.perfil, action);
  }

  Propriedade? propriedadePorId(String id) {
    for (final p in _propriedades) {
      if (p.id == id) return p;
    }
    return null;
  }

  Talhao? talhaoPorId(String id) {
    for (final t in _talhoes) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<RegistroCampo> registrosDoTalhao(String talhaoId) {
    final list = _registros.where((r) => r.talhaoId == talhaoId).toList();
    list.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    return list;
  }

  List<RegistroCampo> ocorrenciasDoTalhao(String talhaoId) {
    return registrosDoTalhao(talhaoId)
        .where((r) => r.tipo == TipoRegistroCampo.ocorrencia)
        .toList();
  }

  List<Alerta> alertasAtivosDoTalhao(String talhaoId) {
    return _alertas.where((a) => a.talhaoId == talhaoId && a.ativo).toList();
  }

  ClimaInfo? climaDaPropriedade(String propriedadeId) =>
      _climaPorPropriedade[propriedadeId];

  String? erroClimaDaPropriedade(String propriedadeId) =>
      _climaErroPorPropriedade[propriedadeId];

  bool carregandoClimaDaPropriedade(String propriedadeId) =>
      _carregandoClima.contains(propriedadeId);

  /// Filtra e ordena os talhões conforme critérios da tela principal.
  List<Talhao> filtrarTalhoes({
    String busca = '',
    String? propriedadeId,
    String? cultura,
    SituacaoTalhao? situacao,
    bool apenasComAlerta = false,
    TalhaoOrdenacao ordenacao = TalhaoOrdenacao.ultimaAtualizacao,
  }) {
    final termo = busca.trim().toLowerCase();
    final filtrados = _talhoes.where((t) {
      if (propriedadeId != null &&
          propriedadeId.isNotEmpty &&
          t.propriedadeId != propriedadeId) {
        return false;
      }
      if (cultura != null &&
          cultura.isNotEmpty &&
          t.cultura.toLowerCase() != cultura.toLowerCase()) {
        return false;
      }
      if (situacao != null && t.situacao != situacao) {
        return false;
      }
      if (apenasComAlerta && alertasAtivosDoTalhao(t.id).isEmpty) {
        return false;
      }
      if (termo.isNotEmpty) {
        final propNome = propriedadePorId(t.propriedadeId)?.nome.toLowerCase() ?? '';
        final match = t.identificacao.toLowerCase().contains(termo) ||
            t.cultura.toLowerCase().contains(termo) ||
            propNome.contains(termo);
        if (!match) return false;
      }
      return true;
    }).toList();

    switch (ordenacao) {
      case TalhaoOrdenacao.ultimaAtualizacao:
        filtrados.sort(
          (a, b) => b.ultimaAtualizacao.compareTo(a.ultimaAtualizacao),
        );
      case TalhaoOrdenacao.colheitaProxima:
        filtrados.sort(
          (a, b) => a.previsaoColheita.compareTo(b.previsaoColheita),
        );
      case TalhaoOrdenacao.umidadeCrescente:
        filtrados.sort((a, b) => a.umidade.compareTo(b.umidade));
      case TalhaoOrdenacao.identificacaoAz:
        filtrados.sort(
          (a, b) => a.identificacao
              .toLowerCase()
              .compareTo(b.identificacao.toLowerCase()),
        );
    }

    return filtrados;
  }

  /// Inicializa sessão salva e carrega os dados da fazenda.
  Future<void> init() async {
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final restored = await _repository.restoreSession();
      _currentUser = restored;
      if (restored != null) {
        await _loadSnapshot(restored);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String senha,
  }) async {
    await _runBusy(() async {
      final user = await _repository.login(email: email, senha: senha);
      _currentUser = user;
      await _loadSnapshot(user);
    });
  }

  Future<void> register({
    required String nome,
    required String email,
    required String senha,
    required UserRole perfil,
  }) async {
    await _runBusy(() async {
      final user = await _repository.register(
        nome: nome,
        email: email,
        senha: senha,
        perfil: perfil,
      );
      _currentUser = user;
      await _loadSnapshot(user);
    });
  }

  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    _propriedades = [];
    _talhoes = [];
    _registros = [];
    _alertas = [];
    _climaPorPropriedade.clear();
    _climaErroPorPropriedade.clear();
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshData() async {
    final user = _currentUser;
    if (user == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadSnapshot(user);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSnapshot(AppUser user) async {
    final snapshot = await _repository.loadAll(user);
    _propriedades = snapshot.propriedades;
    _talhoes = snapshot.talhoes;
    _registros = snapshot.registros;
    _alertas = snapshot.alertas;
    await _reavaliarTodosTalhoes();
  }

  Future<void> _reavaliarTodosTalhoes() async {
    final novos = <Alerta>[];
    final resolvidos = <String>[];
    for (final t in _talhoes) {
      final eval = AlertEngine.avaliar(
        talhao: t,
        alertasExistentes: [..._alertas, ...novos],
      );
      novos.addAll(eval.novosAlertas);
      resolvidos.addAll(eval.alertasResolvidosIds);
    }

    if (novos.isNotEmpty || resolvidos.isNotEmpty) {
      await _repository.sincronizarAlertas(
        novosAlertas: novos,
        alertasResolvidosIds: resolvidos,
      );
      final user = _currentUser;
      if (user != null) {
        final updated = await _repository.loadAll(user);
        _alertas = updated.alertas;
      }
    }
  }

  /// Tenta resolver coordenadas reais via Open-Meteo Geocoding API ao cadastrar
  /// ou atualizar uma propriedade.
  Future<GeoCoordinates?> buscarCoordenadasMunicipio(
    String municipio,
    String estado,
  ) {
    return _weatherService.geocodificarMunicipio(municipio, estado);
  }

  Future<void> salvarPropriedade({
    String? id,
    required String nome,
    required String municipio,
    required String estado,
    required double areaTotalHa,
    required double latitude,
    required double longitude,
  }) async {
    final user = _requireUser();
    await _runBusy(() async {
      final isUpdate = id != null && id.isNotEmpty;
      final existing = isUpdate ? propriedadePorId(id) : null;
      final prop = Propriedade(
        id: isUpdate ? id : IdGenerator.uuidV4(),
        nome: nome.trim(),
        municipio: municipio.trim(),
        estado: estado.trim().toUpperCase(),
        areaTotalHa: areaTotalHa,
        latitude: latitude,
        longitude: longitude,
        criadoPor: existing?.criadoPor ?? user.id,
        criadoEm: existing?.criadoEm ?? DateTime.now(),
      );
      await _repository.savePropriedade(
        user: user,
        propriedade: prop,
        isUpdate: isUpdate,
      );
      await _loadSnapshot(user);
    });
  }

  Future<void> salvarTalhao({
    String? id,
    required String propriedadeId,
    required String identificacao,
    required String cultura,
    required double areaHa,
    required DateTime dataPlantio,
    required DateTime previsaoColheita,
    required double umidade,
    required SituacaoTalhao situacao,
    required String observacoes,
  }) async {
    final user = _requireUser();
    await _runBusy(() async {
      final isUpdate = id != null && id.isNotEmpty;
      final agora = DateTime.now();
      final existing = isUpdate ? talhaoPorId(id) : null;

      final talhao = Talhao(
        id: isUpdate ? id : IdGenerator.uuidV4(),
        propriedadeId: propriedadeId,
        identificacao: identificacao.trim(),
        cultura: cultura.trim(),
        areaHa: areaHa,
        dataPlantio: dataPlantio,
        previsaoColheita: previsaoColheita,
        umidade: umidade,
        situacao: situacao,
        observacoes: observacoes.trim(),
        ultimaAtualizacao: agora,
        criadoPor: existing?.criadoPor ?? user.id,
      );

      final saved = await _repository.saveTalhao(
        user: user,
        talhao: talhao,
        isUpdate: isUpdate,
      );

      final registroPlantio = RegistroCampo(
        id: IdGenerator.uuidV4(),
        talhaoId: saved.id,
        propriedadeId: saved.propriedadeId,
        tipo: TipoRegistroCampo.plantio,
        titulo: isUpdate
            ? 'Dados de plantio atualizados (${saved.cultura})'
            : 'Plantio registrado: ${saved.cultura}',
        descricao: saved.observacoes.isEmpty
            ? 'Área: ${saved.areaHa.toStringAsFixed(1)} ha | Umidade inicial: ${saved.umidade.toStringAsFixed(1)}%'
            : saved.observacoes,
        umidadeRegistrada: saved.umidade,
        situacaoRegistrada: saved.situacao,
        autorNome: user.nome,
        autorPerfil: user.perfil,
        criadoEm: agora,
      );

      final eval = AlertEngine.avaliar(
        talhao: saved,
        alertasExistentes: _alertas,
        novoRegistro: registroPlantio,
        referencia: agora,
      );

      await _repository.registrarEventoCampo(
        user: user,
        talhaoAtualizado: saved,
        registro: registroPlantio,
        novosAlertas: eval.novosAlertas,
        alertasResolvidosIds: eval.alertasResolvidosIds,
      );

      await _loadSnapshot(user);
    });
  }

  Future<void> registrarCondicao({
    required Talhao talhao,
    required double umidade,
    required SituacaoTalhao situacao,
    required String observacoes,
  }) async {
    final user = _requireUser();
    await _runBusy(() async {
      final agora = DateTime.now();
      final atualizado = talhao.copyWith(
        umidade: umidade,
        situacao: situacao,
        observacoes: observacoes.trim().isEmpty
            ? talhao.observacoes
            : observacoes.trim(),
        ultimaAtualizacao: agora,
      );

      final registro = RegistroCampo(
        id: IdGenerator.uuidV4(),
        talhaoId: talhao.id,
        propriedadeId: talhao.propriedadeId,
        tipo: TipoRegistroCampo.condicao,
        titulo: 'Atualização de condição: ${situacao.label}',
        descricao: observacoes.trim().isEmpty
            ? 'Umidade medida em campo: ${umidade.toStringAsFixed(1)}%.'
            : observacoes.trim(),
        umidadeRegistrada: umidade,
        situacaoRegistrada: situacao,
        autorNome: user.nome,
        autorPerfil: user.perfil,
        criadoEm: agora,
      );

      final eval = AlertEngine.avaliar(
        talhao: atualizado,
        alertasExistentes: _alertas,
        novoRegistro: registro,
        referencia: agora,
      );

      await _repository.registrarEventoCampo(
        user: user,
        talhaoAtualizado: atualizado,
        registro: registro,
        novosAlertas: eval.novosAlertas,
        alertasResolvidosIds: eval.alertasResolvidosIds,
      );

      await _loadSnapshot(user);
    });
  }

  Future<void> registrarOcorrencia({
    required Talhao talhao,
    required CategoriaOcorrencia categoria,
    required Severidade severidade,
    required String titulo,
    required String descricao,
    SituacaoTalhao? novaSituacao,
  }) async {
    final user = _requireUser();
    await _runBusy(() async {
      final agora = DateTime.now();
      final situacaoFinal = novaSituacao ??
          (severidade == Severidade.alta
              ? SituacaoTalhao.critico
              : (talhao.situacao == SituacaoTalhao.saudavel
                  ? SituacaoTalhao.atencao
                  : talhao.situacao));

      final atualizado = talhao.copyWith(
        situacao: situacaoFinal,
        ultimaAtualizacao: agora,
      );

      final registro = RegistroCampo(
        id: IdGenerator.uuidV4(),
        talhaoId: talhao.id,
        propriedadeId: talhao.propriedadeId,
        tipo: TipoRegistroCampo.ocorrencia,
        categoriaOcorrencia: categoria,
        severidade: severidade,
        titulo: titulo.trim(),
        descricao: descricao.trim(),
        umidadeRegistrada: talhao.umidade,
        situacaoRegistrada: situacaoFinal,
        autorNome: user.nome,
        autorPerfil: user.perfil,
        criadoEm: agora,
      );

      final eval = AlertEngine.avaliar(
        talhao: atualizado,
        alertasExistentes: _alertas,
        novoRegistro: registro,
        referencia: agora,
      );

      await _repository.registrarEventoCampo(
        user: user,
        talhaoAtualizado: atualizado,
        registro: registro,
        novosAlertas: eval.novosAlertas,
        alertasResolvidosIds: eval.alertasResolvidosIds,
      );

      await _loadSnapshot(user);
    });
  }

  Future<void> resolverAlerta(String alertaId) async {
    final user = _requireUser();
    await _runBusy(() async {
      await _repository.resolverAlerta(user: user, alertaId: alertaId);
      await _loadSnapshot(user);
    });
  }

  /// Consulta condições climáticas reais via API Open-Meteo para a propriedade.
  Future<void> carregarClimaPropriedade(
    Propriedade propriedade, {
    bool force = false,
  }) async {
    if (_carregandoClima.contains(propriedade.id)) return;
    if (!force && _climaPorPropriedade.containsKey(propriedade.id)) return;

    _carregandoClima.add(propriedade.id);
    _climaErroPorPropriedade.remove(propriedade.id);
    notifyListeners();

    try {
      final info = await _weatherService.buscarClimaAtual(
        latitude: propriedade.latitude,
        longitude: propriedade.longitude,
      );
      _climaPorPropriedade[propriedade.id] = info;
    } catch (e) {
      _climaErroPorPropriedade[propriedade.id] = e.toString();
    } finally {
      _carregandoClima.remove(propriedade.id);
      notifyListeners();
    }
  }

  AppUser _requireUser() {
    final user = _currentUser;
    if (user == null) {
      throw RepositoryException('Sessão expirada. Faça login novamente.');
    }
    return user;
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
