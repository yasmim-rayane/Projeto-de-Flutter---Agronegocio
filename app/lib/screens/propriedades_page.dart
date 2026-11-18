import 'package:material_ui/material_ui.dart';

import '../models/propriedade.dart';
import '../services/permission_service.dart';
import '../state/agro_controller.dart';
import '../utils/formatters.dart';

/// Tela de listagem e cadastro de propriedades agrícolas com geocodificação Open-Meteo.
class PropriedadesPage extends StatelessWidget {
  const PropriedadesPage({super.key, required this.controller});

  final AgroController controller;

  Future<void> _abrirFormulario(
    BuildContext context, {
    Propriedade? propriedade,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PropriedadeFormPage(
          controller: controller,
          propriedade: propriedade,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final podeCadastrar =
        controller.can(PermissionAction.cadastrarPropriedade);
    final propriedades = controller.propriedades;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Propriedades e Áreas'),
      ),
      floatingActionButton: podeCadastrar
          ? FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(context),
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Nova Propriedade'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: controller.refreshData,
        child: propriedades.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.landscape_outlined, size: 48),
                          const SizedBox(height: 10),
                          const Text(
                            'Nenhuma propriedade cadastrada.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            podeCadastrar
                                ? 'Cadastre uma fazenda ou área agrícola para vincular talhões.'
                                : 'Seu perfil possui acesso somente leitura para propriedades.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 88),
                itemCount: propriedades.length,
                itemBuilder: (context, index) {
                  final prop = propriedades[index];
                  final talhoesDaProp = controller.talhoes
                      .where((t) => t.propriedadeId == prop.id)
                      .toList();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.agriculture,
                                  color: Color(0xFF1B5E20),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    prop.nome,
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (podeCadastrar)
                                  IconButton(
                                    tooltip: 'Editar propriedade',
                                    onPressed: () => _abrirFormulario(
                                      context,
                                      propriedade: prop,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Localização: ${prop.localizacao}'),
                            Text(
                              'Área total: ${prop.areaTotalHa.toStringAsFixed(1)} ha • ${talhoesDaProp.length} talhão(ões)',
                            ),
                            Text(
                              'Coordenadas: ${prop.latitude.toStringAsFixed(4)}, ${prop.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PropriedadeFormPage extends StatefulWidget {
  const _PropriedadeFormPage({
    required this.controller,
    this.propriedade,
  });

  final AgroController controller;
  final Propriedade? propriedade;

  @override
  State<_PropriedadeFormPage> createState() => _PropriedadeFormPageState();
}

class _PropriedadeFormPageState extends State<_PropriedadeFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _municipioController;
  late final TextEditingController _estadoController;
  late final TextEditingController _areaController;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  bool _buscandoGeo = false;

  @override
  void initState() {
    super.initState();
    final p = widget.propriedade;
    _nomeController = TextEditingController(text: p?.nome ?? '');
    _municipioController = TextEditingController(text: p?.municipio ?? '');
    _estadoController = TextEditingController(text: p?.estado ?? 'SP');
    _areaController = TextEditingController(
      text: p != null ? p.areaTotalHa.toStringAsFixed(1) : '',
    );
    _latController = TextEditingController(
      text: (p?.latitude ?? -21.1775).toStringAsFixed(4),
    );
    _lonController = TextEditingController(
      text: (p?.longitude ?? -47.8103).toStringAsFixed(4),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _municipioController.dispose();
    _estadoController.dispose();
    _areaController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _buscarCoordenadas() async {
    final municipio = _municipioController.text.trim();
    if (municipio.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o município antes de buscar.')),
      );
      return;
    }

    setState(() => _buscandoGeo = true);
    try {
      final result = await widget.controller.buscarCoordenadasMunicipio(
        municipio,
        _estadoController.text.trim(),
      );
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Município não encontrado na API Open-Meteo.'),
          ),
        );
      } else {
        _latController.text = result.latitude.toStringAsFixed(4);
        _lonController.text = result.longitude.toStringAsFixed(4);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coordenadas obtidas: ${result.nomeResolvido}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _buscandoGeo = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    try {
      await widget.controller.salvarPropriedade(
        id: widget.propriedade?.id,
        nome: _nomeController.text,
        municipio: _municipioController.text,
        estado: _estadoController.text,
        areaTotalHa: AgroFormatters.tryParseDecimal(_areaController.text)!,
        latitude: AgroFormatters.tryParseDecimal(_latController.text)!,
        longitude: AgroFormatters.tryParseDecimal(_lonController.text)!,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.propriedade == null
                ? 'Propriedade cadastrada com sucesso!'
                : 'Propriedade atualizada com sucesso!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.propriedade != null;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final busy = widget.controller.isSubmitting;
        return Scaffold(
          appBar: AppBar(
            title: Text(editando ? 'Editar Propriedade' : 'Nova Propriedade'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da propriedade ou área',
                      hintText: 'Ex.: Fazenda Boa Esperança',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Informe o nome da propriedade.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _municipioController,
                          decoration: const InputDecoration(
                            labelText: 'Município',
                            hintText: 'Ex.: Londrina',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 2) {
                              return 'Informe o município.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _estadoController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 2,
                          decoration: const InputDecoration(
                            labelText: 'UF',
                            counterText: '',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length != 2) {
                              return 'UF';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _areaController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Área total (hectares)',
                      suffixText: 'ha',
                    ),
                    validator: (v) {
                      final num = AgroFormatters.tryParseDecimal(v ?? '');
                      if (num == null || num <= 0) {
                        return 'Informe uma área válida maior que zero.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _buscandoGeo ? null : _buscarCoordenadas,
                    icon: _buscandoGeo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text(
                      'Buscar coordenadas via API Open-Meteo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                          ),
                          validator: (v) {
                            final num = AgroFormatters.tryParseDecimal(v ?? '');
                            if (num == null || num < -90 || num > 90) {
                              return 'Latitude entre -90 e 90.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lonController,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: true,
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                          ),
                          validator: (v) {
                            final num = AgroFormatters.tryParseDecimal(v ?? '');
                            if (num == null || num < -180 || num > 180) {
                              return 'Longitude entre -180 e 180.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: busy ? null : _salvar,
                    child: Text(editando ? 'Salvar alterações' : 'Cadastrar propriedade'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
