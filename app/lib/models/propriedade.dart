/// Representa uma propriedade ou área agrícola cadastrada no sistema.
class Propriedade {
  const Propriedade({
    required this.id,
    required this.nome,
    required this.municipio,
    required this.estado,
    required this.areaTotalHa,
    required this.latitude,
    required this.longitude,
    required this.criadoPor,
    required this.criadoEm,
  });

  final String id;
  final String nome;
  final String municipio;
  final String estado;
  final double areaTotalHa;
  final double latitude;
  final double longitude;
  final String criadoPor;
  final DateTime criadoEm;

  String get localizacao => '$municipio/$estado';

  Propriedade copyWith({
    String? id,
    String? nome,
    String? municipio,
    String? estado,
    double? areaTotalHa,
    double? latitude,
    double? longitude,
    String? criadoPor,
    DateTime? criadoEm,
  }) {
    return Propriedade(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      municipio: municipio ?? this.municipio,
      estado: estado ?? this.estado,
      areaTotalHa: areaTotalHa ?? this.areaTotalHa,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      criadoPor: criadoPor ?? this.criadoPor,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }

  factory Propriedade.fromMap(Map<String, dynamic> map) {
    return Propriedade(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      municipio: map['municipio']?.toString() ?? '',
      estado: map['estado']?.toString() ?? '',
      areaTotalHa: (map['area_total_ha'] as num?)?.toDouble() ?? 0.0,
      latitude: (map['latitude'] as num?)?.toDouble() ?? -21.1775,
      longitude: (map['longitude'] as num?)?.toDouble() ?? -47.8103,
      criadoPor: map['criado_por']?.toString() ?? '',
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'municipio': municipio,
      'estado': estado,
      'area_total_ha': areaTotalHa,
      'latitude': latitude,
      'longitude': longitude,
      'criado_por': criadoPor.isEmpty ? null : criadoPor,
      'criado_em': criadoEm.toUtc().toIso8601String(),
    };
  }
}

