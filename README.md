# AgroCampo MVP — Acompanhamento de Talhões e Atividades Agrícolas

Aplicativo móvel desenvolvido em **Dart e Flutter** com base no edital `03_Agronegocio - edital.pdf` e no material da disciplina.

## 1. Objetivo

Centralizar o acompanhamento em campo dos talhões e das atividades agrícolas, permitindo que a equipe identifique rapidamente:
- **O que está plantado** em cada área (cultura e hectares);
- **Quando ocorreu o plantio**;
- **Qual é a condição atual** do talhão (umidade do solo, situação operacional e observações);
- **Quais ocorrências foram registradas** (pragas, doenças, déficit hídrico, clima, manejo);
- **Quando a colheita está prevista** (com dias restantes ou indicação de atraso).

---

## 2. Funcionalidades Implementadas

- **Autenticação com validação**: Login e Cadastro com escolha de perfil de acesso, incluindo feedback visual positivo (verde) tanto no acesso imediato quanto quando o Supabase aguarda confirmação de e-mail (`EmailConfirmationRequiredException`).
- **Perfis e permissões**: Controle de acesso aplicado na navegação/UI, na camada de serviço (`PermissionService`) e nas políticas remotas do banco (`Row Level Security` e `GRANT`s explícitos em `app/supabase/schema.sql`).
- **Propriedades / Áreas**: Listagem, cadastro e edição com geocodificação automática via **API Open-Meteo Geocoding**.
- **Talhões e Plantio**: Cadastro e edição vinculados à propriedade, validação de área (`> 0` e `<= área total da propriedade`) e validação de datas (`previsão de colheita >= data de plantio`).
- **Acompanhamento de Campo e Histórico**: Atualização de condição atual (umidade com `Slider`, situação e observações), registro de ocorrências e histórico cronológico por talhão.
- **Busca, Filtros e Ordenação**: Busca textual por identificação/cultura/propriedade, filtros combinados por propriedade, cultura, situação e presença de alertas, além de ordenação (mais recentes, colheita próxima, menor umidade, A-Z).
- **Motor Automático de Alertas (`AlertEngine`)**: Geração e resolução automática de alertas reais vinculados ao talhão.
- **Clima em Tempo Real**: Consulta meteorológica da propriedade via **API Open-Meteo Forecast** na tela de detalhes do talhão.

---

## 3. Tecnologias Utilizadas

- **Dart 3.14+ / Flutter 3.50+** (`material_ui`, `StatefulWidget`, `ChangeNotifier`, `Navigator.push`/`pop`)
- **`http`**: Comunicação REST com a API Open-Meteo e com o Supabase (Auth + PostgREST)
- **`shared_preferences`**: Persistência de sessão e modo demonstração local persistido entre reinicializações
- **Supabase (PostgreSQL + GoTrue + PostgREST + RLS)**: Persistência remota estruturada em `app/supabase/schema.sql`
- **Open-Meteo API**: API pública externa para geocodificação de municípios e clima atual em campo
- **ngrok (opcional)**: Exposição do servidor local (`build/web`) via HTTPS para acesso externo em outros dispositivos/redes

---

## 4. Entidades, Relacionamentos e Regras de Implementação

### Entidades Principais
1. **`AppUser` (`perfis`)**: `id`, `nome`, `email`, `perfil` (`UserRole`).
2. **`Propriedade` (`propriedades`)**: `id`, `nome`, `municipio`, `estado`, `areaTotalHa`, `latitude`, `longitude`, `criadoPor`, `criadoEm`.
3. **`Talhao` (`talhoes`)**: `id`, `propriedadeId` (FK -> `Propriedade`), `identificacao`, `cultura`, `areaHa`, `dataPlantio`, `previsaoColheita`, `umidade`, `situacao`, `observacoes`, `ultimaAtualizacao`.
4. **`RegistroCampo` (`registros_campo`)**: `id`, `talhaoId` (FK -> `Talhao`), `propriedadeId` (FK), `tipo` (`plantio` | `condicao` | `ocorrencia`), `categoriaOcorrencia`, `severidade`, `titulo`, `descricao`, `umidadeRegistrada`, `situacaoRegistrada`, `autorNome`, `autorPerfil`, `criadoEm`.
5. **`Alerta` (`alertas`)**: `id`, `talhaoId` (FK -> `Talhao`), `propriedadeId` (FK), `regra`, `severidade`, `titulo`, `mensagem`, `parametroDisparo`, `ativo`, `criadoEm`, `resolvidoEm`, `resolvidoPor`.
6. **`ClimaInfo`**: `temperaturaC`, `umidadeAr`, `precipitacaoMm`, `ventoKmh`, `descricaoClima`, `atualizadoEm`.

### Regras de Validação (Decisões de Implementação)
- `areaTotalHa > 0` e `areaHa > 0`.
- `areaHa <= propriedade.areaTotalHa` (impede talhão maior que a propriedade cadastrada).
- `previsaoColheita >= dataPlantio` (impede colheita anterior ao plantio).
- `umidade` entre `0%` e `100%`.
- E-mail válido e senha com mínimo de `6` caracteres no login e cadastro.

---

## 5. Perfis e Matriz de Permissões

Como o edital lista os 4 perfis sem fixar uma matriz fechada, adotou-se a seguinte matriz coerente com a operação agrícola (aplicada em UI, `PermissionService` e RLS do Supabase):

| Ação | Gestor da Propriedade | Produtor Rural | Agrônomo | Técnico Agrícola |
| :--- | :---: | :---: | :---: | :---: |
| Consultar propriedades, talhões, histórico e alertas | Sim | Sim | Sim | Sim |
| Cadastrar / editar propriedades | Sim | Sim | Não | Não |
| Cadastrar talhões e editar plantio/cultura | Sim | Sim | Sim | Não |
| Atualizar condição atual (umidade/situação) | Sim | Sim | Sim | Sim |
| Registrar ocorrências em campo | Sim | Sim | Sim | Sim |
| Resolver / encerrar alertas operacionais | Sim | Não | Sim | Não |

---

## 6. Regra de Alerta Automática (`AlertEngine`)

O motor `app/lib/services/alert_engine.dart` avalia automaticamente os dados reais sempre que um talhão é salvo, uma condição é atualizada ou uma ocorrência é registrada:

1. **Umidade abaixo do limite (`umidade < 35.0%`)**:
   - Dispara alerta de severidade *Média* (`25% <= umidade < 35%`) ou *Alta* (`umidade < 25%`) para talhões não colhidos.
   - Se a umidade retornar para `>= 35%`, o alerta ativo correspondente é automaticamente resolvido.
2. **Ocorrência de Praga ou Doença (`categoria == praga` ou `doenca`)**:
   - Dispara alerta vinculado ao `talhaoId` com a mesma severidade da ocorrência registrada.
3. **Proximidade ou Atraso na Colheita**:
   - Se `0 <= diasParaColheita <= 7` (e situação != `Colhido`), dispara alerta de **Proximidade da Colheita** (*Média* ou *Alta* quando `<= 2` dias).
   - Se `diasParaColheita < 0` (e situação != `Colhido`), dispara alerta de **Colheita em Atraso** (*Alta*).
   - Quando o talhão é marcado como `Colhido`, os alertas de prazo são resolvidos automaticamente.

---

## 7. Integração com API Externa (Open-Meteo)

- **API utilizada**: [Open-Meteo](https://open-meteo.com/) (HTTPS pública, sem necessidade de chave administrativa).
- **Onde ocorre**:
  1. **Geocodificação (`geocoding-api.open-meteo.com/v1/search`)**: Na tela `PropriedadesPage` (botão *"Buscar coordenadas via API Open-Meteo"*), convertendo município/UF em latitude e longitude reais.
  2. **Clima Atual (`api.open-meteo.com/v1/forecast`)**: Na tela `TalhaoDetalhePage` (componente `ClimaCard`), buscando temperatura, umidade relativa do ar, precipitação, vento e código meteorológico WMO para apoiar decisões de manejo no campo.

---

## 8. WidgetTree Simplificada do Aplicativo

```text
AgroCampoApp (StatelessWidget)
└── MaterialApp
    └── AnimatedBuilder (escuta AgroController)
        ├── [Não autenticado] LoginPage (StatefulWidget)
        │   └── Scaffold -> SafeArea -> SingleChildScrollView -> Card -> Form
        │       ├── TextFormField (E-mail)
        │       ├── TextFormField (Senha)
        │       ├── ElevatedButton ('Entrar')
        │       └── OutlinedButton ('Criar nova conta') -> Navigator.push(CadastroPage)
        │
        └── [Autenticado] MainShellPage (StatefulWidget)
            └── Scaffold
                ├── IndexedStack
                │   ├── [0] TalhoesListPage
                │   │   └── Scaffold (AppBar, FAB condicionado a permissão)
                │   │       └── RefreshIndicator -> ListView
                │   │           ├── Row -> Expanded -> ResumoMetricCard (x3)
                │   │           ├── TextField (Busca) + Dropdowns/Chips (Filtros)
                │   │           └── TalhaoCard -> Navigator.push(TalhaoDetalhePage)
                │   │               └── Scaffold -> ListView
                │   │                   ├── Card (Resumo do talhão)
                │   │                   ├── Row (Botões Atualizar Condição / Ocorrência)
                │   │                   ├── ClimaCard (API Open-Meteo)
                │   │                   ├── AlertaCard (Alertas ativos do talhão)
                │   │                   └── _HistoricoItemCard (Registros em campo)
                │   ├── [1] AlertasPage
                │   │   └── Scaffold -> RefreshIndicator -> ListView -> SegmentedButton + AlertaCard
                │   ├── [2] PropriedadesPage
                │   │   └── Scaffold -> ListView -> Card (Propriedades)
                │   └── [3] PerfilPage
                │       └── Scaffold -> ListView -> CircleAvatar + Lista de Permissões + Logout
                └── NavigationBar (4 destinos com Badge de alertas)
```

---

## 9. Estrutura da Pasta e Execução

```text
agro_campo/
├── Abrir AgroCampo.bat                 # Inicia o app localmente no navegador (2 cliques)
├── Abrir AgroCampo Online (ngrok).bat  # Inicia o app + túnel ngrok para outro Wi-Fi/4G
├── README.md                           # Documentação do projeto
└── app/                                # Código-fonte e projeto Flutter completo
    ├── lib/
    ├── test/
    ├── supabase/schema.sql
    └── pubspec.yaml
```

### Execução Rápida (2 cliques no Windows)
- **Uso local (`Abrir AgroCampo.bat`)**: Sobe o servidor estático de `app/build/web` em `http://localhost:8085` (já compilado com a conexão Supabase configurada) e abre no navegador padrão.
- **Acesso externo via outro Wi-Fi ou 4G (`Abrir AgroCampo Online (ngrok).bat`)**: Sobe o servidor local em `127.0.0.1:8085` e abre um túnel `ngrok` exibindo a URL pública `https://...ngrok-free.app` para acessar de qualquer celular ou computador enquanto o PC estiver ligado.

### Passo 1 — Instalar dependências (desenvolvimento)
```bash
cd app
flutter pub get
```

### Passo 2 — Configurar Supabase (modo remoto)
1. Crie um projeto gratuito no [Supabase](https://supabase.com/).
2. Abra o **SQL Editor** do projeto e execute todo o arquivo `app/supabase/schema.sql` (ele já inclui os `GRANT`s de schema/tabelas para a Data API, evitando erros de permissão quando *"Automatically expose new tables"* não estiver marcado).
3. Em *Authentication -> Providers -> Email*, garanta que o login por e-mail/senha esteja habilitado (para testes imediatos sem confirmação por e-mail, desative temporariamente *"Confirm email"*).
4. Execute o app passando as credenciais via `--dart-define`:
```bash
cd app
flutter run -d chrome --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_ANON_KEY=SUA_ANON_KEY
```

> **Modo Demonstração Local:** Caso `SUPABASE_URL` e `SUPABASE_ANON_KEY` não sejam informados, o aplicativo opera automaticamente com `LocalAgroRepository` (persistido localmente via `SharedPreferences`), exibindo aviso explícito na interface e permitindo testar os 4 perfis imediatamente (senha padrão demo: `123456`).

### Passo 3 — Análise estática e testes
```bash
cd app
flutter analyze
flutter test
```
