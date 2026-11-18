import 'package:material_ui/material_ui.dart';

import '../models/registro_campo.dart';
import '../models/talhao.dart';
import '../state/agro_controller.dart';

enum RegistroModo { condicao, ocorrencia }

/// Formulário de campo para atualizar condição atual ou registrar ocorrência.
class RegistroCampoPage extends StatefulWidget {
  const RegistroCampoPage({
    super.key,
    required this.controller,
    required this.talhao,
    required this.modo,
  });

  final AgroController controller;
  final Talhao talhao;
  final RegistroModo modo;

  @override
  State<RegistroCampoPage> createState() => _RegistroCampoPageState();
}

class _RegistroCampoPageState extends State<RegistroCampoPage> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();

  late double _umidade;
  late SituacaoTalhao _situacao;
  CategoriaOcorrencia _categoria = CategoriaOcorrencia.praga;
  Severidade _severidade = Severidade.media;

  @override
  void initState() {
    super.initState();
    _umidade = widget.talhao.umidade;
    _situacao = widget.talhao.situacao;
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final ctrl = widget.controller;
    final alertasAntes = ctrl.alertasAtivosDoTalhao(widget.talhao.id).length;

    try {
      if (widget.modo == RegistroModo.condicao) {
        await ctrl.registrarCondicao(
          talhao: widget.talhao,
          umidade: _umidade,
          situacao: _situacao,
          observacoes: _descricaoController.text,
        );
      } else {
        await ctrl.registrarOcorrencia(
          talhao: widget.talhao,
          categoria: _categoria,
          severidade: _severidade,
          titulo: _tituloController.text,
          descricao: _descricaoController.text,
          novaSituacao: _situacao,
        );
      }

      if (!mounted) return;
      final alertasDepois = ctrl.alertasAtivosDoTalhao(widget.talhao.id).length;
      final gerouNovoAlerta = alertasDepois > alertasAntes;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gerouNovoAlerta
                ? 'Registro salvo! Um novo alerta automático foi gerado para este talhão.'
                : 'Registro salvo no histórico do talhão!',
          ),
          backgroundColor:
              gerouNovoAlerta ? Colors.orange.shade800 : const Color(0xFF1B5E20),
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
    final isCondicao = widget.modo == RegistroModo.condicao;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final busy = widget.controller.isSubmitting;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              isCondicao
                  ? 'Atualizar Condição — ${widget.talhao.identificacao}'
                  : 'Registrar Ocorrência — ${widget.talhao.identificacao}',
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isCondicao) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Umidade do solo medida: ${_umidade.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Slider(
                              value: _umidade,
                              min: 0,
                              max: 100,
                              divisions: 100,
                              label: '${_umidade.toStringAsFixed(0)}%',
                              onChanged: (valor) {
                                setState(() {
                                  _umidade = valor;
                                  if (_umidade < 35 &&
                                      _situacao == SituacaoTalhao.saudavel) {
                                    _situacao = SituacaoTalhao.atencao;
                                  }
                                });
                              },
                            ),
                            Text(
                              _umidade < 35
                                  ? 'Abaixo de 35%: será disparado alerta automático de umidade crítica.'
                                  : 'Faixa adequada (>= 35%).',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _umidade < 35
                                    ? Colors.red.shade700
                                    : Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    DropdownButtonFormField<CategoriaOcorrencia>(
                      initialValue: _categoria,
                      decoration: const InputDecoration(
                        labelText: 'Categoria da ocorrência',
                      ),
                      items: CategoriaOcorrencia.values
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _categoria = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Severidade>(
                      initialValue: _severidade,
                      decoration: const InputDecoration(
                        labelText: 'Severidade',
                      ),
                      items: Severidade.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _severidade = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título da ocorrência',
                        hintText: 'Ex.: Presença de lagarta-da-soja',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 3) {
                          return 'Descreva um título resumido para a ocorrência.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<SituacaoTalhao>(
                    initialValue: _situacao,
                    decoration: const InputDecoration(
                      labelText: 'Situação resultante do talhão',
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
                    controller: _descricaoController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText:
                          isCondicao ? 'Observações da vistoria' : 'Detalhes da ocorrência',
                      hintText: isCondicao
                          ? 'Ex.: Solo seco na borda oeste; prevista irrigação amanhã.'
                          : 'Descreva extensão, área afetada e ação recomendada...',
                    ),
                    validator: (v) {
                      if (!isCondicao && (v == null || v.trim().length < 4)) {
                        return 'Informe os detalhes da ocorrência.';
                      }
                      return null;
                    },
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
                        : Text(
                            isCondicao
                                ? 'Salvar condição atual'
                                : 'Registrar ocorrência',
                          ),
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
