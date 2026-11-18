/// Perfis de usuário previstos no edital para operações agrícolas.
enum UserRole {
  produtorRural('produtor_rural', 'Produtor Rural'),
  agronomo('agronomo', 'Agrônomo'),
  tecnicoAgricola('tecnico_agricola', 'Técnico Agrícola'),
  gestorPropriedade('gestor_propriedade', 'Gestor da Propriedade');

  const UserRole(this.apiValue, this.label);

  /// Valor persistido no banco de dados / API.
  final String apiValue;

  /// Rótulo exibido na interface em português.
  final String label;

  /// Converte a string persistida no correspondente [UserRole].
  static UserRole fromApiValue(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.apiValue == value,
      orElse: () => UserRole.tecnicoAgricola,
    );
  }
}

/// Representa o usuário autenticado no aplicativo.
class AppUser {
  const AppUser({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
  });

  final String id;
  final String nome;
  final String email;
  final UserRole perfil;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      perfil: UserRole.fromApiValue(map['perfil']?.toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'perfil': perfil.apiValue,
    };
  }
}

