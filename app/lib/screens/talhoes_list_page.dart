import 'package:material_ui/material_ui.dart';

import '../models/talhao.dart';
import '../services/permission_service.dart';
import '../state/agro_controller.dart';
import '../widgets/resumo_metric_card.dart';
import '../widgets/talhao_card.dart';
import 'talhao_detalhe_page.dart';
import 'talhao_form_page.dart';

/// Tela principal de campo: listagem, busca, filtros combinados e ordenação de talhões.
class TalhoesListPage extends StatefulWidget {
  const TalhoesListPage({super.key, required this.controller});

  final AgroController controller;

  @override
  State<TalhoesListPage> createState() => _TalhoesListPageState();
}

class _TalhoesListPageState extends State<TalhoesListPage> {
  final _buscaController = TextEditingController();
  String? _propriedadeFiltro;
  String? _culturaFiltro;
  SituacaoTalhao? _situacaoFiltro;
  bool _apenasComAlerta = false;
  TalhaoOrdenacao _ordenacao = TalhaoOrdenacao.ultimaAtualizacao;

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _limparFiltros() {
    setState(() {
      _buscaController.clear();
      _propriedadeFiltro = null;
      _culturaFiltro = null;
      _situacaoFiltro = null;
      _apenasComAlerta = false;
      _ordenacao = TalhaoOrdenacao.ultimaAtualizacao;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final podeCadastrarTalhao = ctrl.can(PermissionAction.cadastrarTalhao);

    final todos = ctrl.talhoes;
    final filtrados = ctrl.filtrarTalhoes(
      busca: _buscaController.text,
      propriedadeId: _propriedadeFiltro,
      cultura: _culturaFiltro,
      situacao: _situacaoFiltro,
      apenasComAlerta: _apenasComAlerta,
      ordenacao: _ordenacao,
    );

    final umidadeMedia = todos.isEmpty
        ? 0.0
        : todos.map((t) => t.umidade).reduce((a, b) => a + b) / todos.length;

    final temFiltroAtivo = _buscaController.text.isNotEmpty ||
        _propriedadeFiltro != null ||
        _culturaFiltro != null ||
        _situacaoFiltro != null ||
        _apenasComAlerta;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acompanhamento de Talhões'),
        actions: [
          PopupMenuButton<TalhaoOrdenacao>(
            tooltip: 'Ordenar talhões',
            icon: const Icon(Icons.sort),
            initialValue: _ordenacao,
            onSelected: (value) => setState(() => _ordenacao = value),
            itemBuilder: (context) => TalhaoOrdenacao.values
                .map(
                  (ord) => PopupMenuItem(
                    value: ord,
                    child: Row(
                      children: [
                        if (ord == _ordenacao)
                          const Icon(Icons.check, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(ord.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          IconButton(
            tooltip: 'Atualizar dados',
            onPressed: ctrl.isLoading ? null : ctrl.refreshData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: podeCadastrarTalhao
          ? FloatingActionButton.extended(
              onPressed: () {
                if (ctrl.propriedades.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Cadastre primeiro uma propriedade na aba Propriedades.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TalhaoFormPage(controller: ctrl),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Novo Talhão'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: ctrl.refreshData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 88),
          children: [
            if (!ctrl.isRemoteMode)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storage_outlined,
                      size: 18,
                      color: Color(0xFF1B5E20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Armazenamento local persistido (${ctrl.currentUser?.perfil.label ?? ''}). Configure SUPABASE_URL e SUPABASE_ANON_KEY para modo remoto.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            if (ctrl.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  ctrl.errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ResumoMetricCard(
                    titulo: 'Talhões',
                    valor: '${todos.length}',
                    icone: Icons.grid_view_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ResumoMetricCard(
                    titulo: 'Alertas',
                    valor: '${ctrl.alertasAtivos.length}',
                    icone: Icons.notifications_active_outlined,
                    cor: ctrl.alertasAtivos.isEmpty
                        ? const Color(0xFF2E7D32)
                        : Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ResumoMetricCard(
                    titulo: 'Umidade méd.',
                    valor: '${umidadeMedia.toStringAsFixed(0)}%',
                    icone: Icons.water_drop_outlined,
                    cor: umidadeMedia < 35 && todos.isNotEmpty
                        ? Colors.orange.shade800
                        : const Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _buscaController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por talhão, cultura ou propriedade...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _buscaController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _buscaController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _propriedadeFiltro,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Propriedade',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas'),
                      ),
                      ...ctrl.propriedades.map(
                        (p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(
                            p.nome,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _propriedadeFiltro = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _culturaFiltro,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cultura',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas'),
                      ),
                      ...ctrl.culturasDisponiveis.map(
                        (c) => DropdownMenuItem<String?>(
                          value: c,
                          child: Text(c),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _culturaFiltro = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Com alerta'),
                    selected: _apenasComAlerta,
                    onSelected: (v) => setState(() => _apenasComAlerta = v),
                  ),
                  const SizedBox(width: 6),
                  ...SituacaoTalhao.values.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(s.label),
                        selected: _situacaoFiltro == s,
                        onSelected: (selected) {
                          setState(() {
                            _situacaoFiltro = selected ? s : null;
                          });
                        },
                      ),
                    ),
                  ),
                  if (temFiltroAtivo)
                    TextButton.icon(
                      onPressed: _limparFiltros,
                      icon: const Icon(Icons.filter_alt_off, size: 18),
                      label: const Text('Limpar'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (ctrl.isLoading && todos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtrados.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 42,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nenhum talhão encontrado com os critérios atuais.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (temFiltroAtivo) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _limparFiltros,
                          child: const Text('Limpar filtros'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              ...filtrados.map(
                (talhao) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TalhaoCard(
                    talhao: talhao,
                    propriedade: ctrl.propriedadePorId(talhao.propriedadeId),
                    ocorrencias: ctrl.ocorrenciasDoTalhao(talhao.id),
                    alertasAtivos: ctrl.alertasAtivosDoTalhao(talhao.id),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TalhaoDetalhePage(
                            controller: ctrl,
                            talhaoId: talhao.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
