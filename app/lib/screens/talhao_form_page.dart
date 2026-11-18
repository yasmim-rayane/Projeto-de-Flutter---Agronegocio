import 'package:material_ui/material_ui.dart';

import '../models/talhao.dart';
import '../state/agro_controller.dart';
import '../utils/formatters.dart';

/// Formulário completo para cadastrar talhão e registrar cultura/plantio.
class TalhaoFormPage extends StatefulWidget {
  const TalhaoFormPage({
    super.key,
    required this.controller,
    this.talhao,
  });

  final AgroController controller;
  final Talhao? talhao;

  @override
  State<TalhaoFormPage> createState() => _TalhaoFormPageState();
}

class _TalhaoFormPageState extends State<TalhaoFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identificacaoController;
  late final TextEditingController _culturaController;
  late final TextEditingController _areaController;
  late final TextEditingController _observacoesController;

  late String _propriedadeId;
  late DateTime _dataPlantio;
  late DateTime _previsaoColheita;
  late double _umidade;
  late SituacaoTalhao _situacao;

  static const _culturasComuns = ['Soja', 'Milho', 'Café', 'Cana-de-açúcar', 'Trigo'];

  @override
  void initState() {
    super.initState();
    final t = widget.talhao;
    final props = widget.controller.propriedades;
    _propriedadeId = t?.propriedadeId ?? (props.isNotEmpty ? props.first.id : '');
    _identificacaoController =
        TextEditingController(text: t?.identificacao ?? '');
    _culturaController = TextEditingController(text: t?.cultura ?? '');
    _areaController = TextEditingController(
      text: t != null ? t.areaHa.toStringAsFixed(1) : '',
    );
    _observacoesController = TextEditingController(text: t?.observacoes ?? '');

    final agora = DateTime.now();
    _dataPlantio = t?.dataPlantio ?? agora;
    _previsaoColheita =
        t?.previsaoColheita ?? agora.add(const Duration(days: 110));
    _umidade = t?.umidade ?? 55.0;
    _situacao = t?.situacao ?? SituacaoTalhao.saudavel;
  }

  @override
  void dispose() {
    _identificacaoController.dispose();
    _culturaController.dispose();
    _areaController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData({required bool isPlantio}) async {
    final inicial = isPlantio ? _dataPlantio : _previsaoColheita;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (escolhida == null) return;
    setState(() {
      if (isPlantio) {
        _dataPlantio = escolhida;
      } else {
        _previsaoColheita = escolhida;
      }
    });
  }

  bool get _datasInvalidas {
    final p = DateTime(_dataPlantio.year, _dataPlantio.month, _dataPlantio.day);
    final c = DateTime(
      _previsaoColheita.year,
      _previsaoColheita.month,
      _previsaoColheita.day,
    );
    return c.isBefore(p);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_datasInvalidas) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'A previsão de colheita não pode ser anterior à data de plantio.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    try {
      await widget.controller.salvarTalhao(
        id: widget.talhao?.id,
        propriedadeId: _propriedadeId,
        identificacao: _identificacaoController.text,
        cultura: _culturaController.text,
        areaHa: AgroFormatters.tryParseDecimal(_areaController.text)!,
        dataPlantio: _dataPlantio,
        previsaoColheita: _previsaoColheita,
        umidade: _umidade,
        situacao: _situacao,
        observacoes: _observacoesController.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.talhao == null
                ? 'Talhão e plantio registrados com sucesso!'
                : 'Dados do talhão atualizados!',
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
    final editando = widget.talhao != null;
    final propriedades = widget.controller.propriedades;
    final propSelecionada = widget.controller.propriedadePorId(_propriedadeId);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final busy = widget.controller.isSubmitting;
        return Scaffold(
          appBar: AppBar(
            title: Text(editando ? 'Editar Talhão e Plantio' : 'Novo Talhão e Plantio'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _propriedadeId.isEmpty ? null : _propriedadeId,
                    decoration: const InputDecoration(
                      labelText: 'Propriedade vinculada',
                      prefixIcon: Icon(Icons.landscape_outlined),
                    ),
                    items: propriedades
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.nome} (${p.areaTotalHa.toStringAsFixed(0)} ha)'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _propriedadeId = value);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Selecione uma propriedade.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _identificacaoController,
                    decoration: const InputDecoration(
                      labelText: 'Identificação do talhão',
                      hintText: 'Ex.: Talhão C3 - Encosta',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Informe a identificação do talhão.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _culturaController,
                    decoration: const InputDecoration(
                      labelText: 'Cultura plantada',
                      hintText: 'Ex.: Soja, Milho, Café',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Informe a cultura plantada.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _culturasComuns
                        .map(
                          (cultura) => ActionChip(
                            label: Text(cultura),
                            onPressed: () {
                              _culturaController.text = cultura;
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _areaController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Área do talhão (ha)',
                      suffixText: 'ha',
                    ),
                    validator: (v) {
                      final area = AgroFormatters.tryParseDecimal(v ?? '');
                      if (area == null || area <= 0) {
                        return 'Informe uma área válida maior que zero.';
                      }
                      if (propSelecionada != null &&
                          area > propSelecionada.areaTotalHa) {
                        return 'Área excede o total da propriedade (${propSelecionada.areaTotalHa.toStringAsFixed(1)} ha).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selecionarData(isPlantio: true),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            'Plantio: ${AgroFormatters.formatDate(_dataPlantio)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selecionarData(isPlantio: false),
                          icon: const Icon(Icons.event_available_outlined),
                          label: Text(
                            'Colheita: ${AgroFormatters.formatDate(_previsaoColheita)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_datasInvalidas)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Atenção: a previsão de colheita deve ser igual ou posterior ao plantio.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Umidade inicial/atual do solo: ${_umidade.toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Slider(
                            value: _umidade,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            label: '${_umidade.toStringAsFixed(0)}%',
                            onChanged: (valor) {
                              setState(() => _umidade = valor);
                            },
                          ),
                          Text(
                            'Regra automática: umidade abaixo de 35% gera alerta operacional.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SituacaoTalhao>(
                    initialValue: _situacao,
                    decoration: const InputDecoration(
                      labelText: 'Situação atual',
                    ),
                    items: SituacaoTalhao.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _situacao = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _observacoesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Observações de campo',
                      hintText: 'Informações sobre cultivar, adubação ou manejo...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: busy ? null : _salvar,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(editando
                            ? 'Salvar alterações do talhão'
                            : 'Cadastrar talhão e plantio'),
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
