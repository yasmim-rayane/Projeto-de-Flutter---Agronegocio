import '../models/usuario.dart';

/// Ações de negócio sujeitas a controle de acesso por perfil.
enum PermissionAction {
  consultarDados('Consultar propriedades, talhões, histórico e alertas'),
  cadastrarPropriedade('Cadastrar e editar propriedades/áreas'),
  cadastrarTalhao('Cadastrar novos talhões'),
  editarPlantioTalhao('Editar cultura, área e datas de plantio/colheita'),
  atualizarCondicaoTalhao('Atualizar umidade, situação e observações de campo'),
  registrarOcorrencia('Registrar ocorrências em campo'),
  resolverAlerta('Encerrar/resolver alertas operacionais');

  const PermissionAction(this.descricao);

  final String descricao;
}

/// Exceção lançada quando um usuário tenta executar operação sem permissão.
class PermissionDeniedException implements Exception {
  PermissionDeniedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Centraliza a matriz de permissões dos quatro perfis citados no edital.
class PermissionService {
  static const Map<UserRole, Set<PermissionAction>> _matriz = {
    UserRole.gestorPropriedade: {
      PermissionAction.consultarDados,
      PermissionAction.cadastrarPropriedade,
      PermissionAction.cadastrarTalhao,
      PermissionAction.editarPlantioTalhao,
      PermissionAction.atualizarCondicaoTalhao,
      PermissionAction.registrarOcorrencia,
      PermissionAction.resolverAlerta,
    },
    UserRole.produtorRural: {
      PermissionAction.consultarDados,
      PermissionAction.cadastrarPropriedade,
      PermissionAction.cadastrarTalhao,
      PermissionAction.editarPlantioTalhao,
      PermissionAction.atualizarCondicaoTalhao,
      PermissionAction.registrarOcorrencia,
    },
    UserRole.agronomo: {
      PermissionAction.consultarDados,
      PermissionAction.cadastrarTalhao,
      PermissionAction.editarPlantioTalhao,
      PermissionAction.atualizarCondicaoTalhao,
      PermissionAction.registrarOcorrencia,
      PermissionAction.resolverAlerta,
    },
    UserRole.tecnicoAgricola: {
      PermissionAction.consultarDados,
      PermissionAction.atualizarCondicaoTalhao,
      PermissionAction.registrarOcorrencia,
    },
  };

  /// Retorna `true` se o [role] possuir permissão para [action].
  static bool can(UserRole role, PermissionAction action) {
    return _matriz[role]?.contains(action) ?? false;
  }

  /// Garante a autorização na camada de serviço/repositório antes de operar dados.
  static void ensureAllowed(UserRole role, PermissionAction action) {
    if (!can(role, action)) {
      throw PermissionDeniedException(
        'Perfil "${role.label}" não possui permissão para: ${action.descricao}.',
      );
    }
  }

  /// Lista todas as ações permitidas para exibição transparente no perfil.
  static List<PermissionAction> allowedActions(UserRole role) {
    return PermissionAction.values
        .where((action) => can(role, action))
        .toList();
  }
}

