import 'package:material_ui/material_ui.dart';

import '../state/agro_controller.dart';
import 'cadastro_page.dart';

/// Tela de autenticação com validação de formulário e feedback de erros.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});

  final AgroController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    try {
      await widget.controller.login(
        email: _emailController.text,
        senha: _senhaController.text,
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

  void _preencherDemo(String email) {
    _emailController.text = email;
    _senhaController.text = '123456';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final busy = widget.controller.isSubmitting;
        final isRemote = widget.controller.isRemoteMode;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.agriculture_rounded,
                        size: 64,
                        color: Color(0xFF1B5E20),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'AgroCampo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Acompanhamento de talhões, plantio, ocorrências e alertas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Entrar no sistema',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'E-mail',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return 'Informe o e-mail.';
                                    }
                                    if (!text.contains('@') ||
                                        !text.contains('.')) {
                                      return 'Informe um e-mail válido.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _senhaController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Senha',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Informe a senha.';
                                    }
                                    if (value.length < 6) {
                                      return 'A senha deve ter ao menos 6 caracteres.';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                const SizedBox(height: 18),
                                ElevatedButton(
                                  onPressed: busy ? null : _submit,
                                  child: busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Entrar'),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CadastroPage(
                                                controller: widget.controller,
                                              ),
                                            ),
                                          );
                                        },
                                  child: const Text('Criar nova conta'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (!isRemote)
                        Card(
                          color: const Color(0xFFE8F5E9),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Modo Demonstração Local (sem SUPABASE_URL)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF1B5E20),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Toque em um perfil para testar rapidamente permissões (senha padrão: 123456):',
                                  style: TextStyle(fontSize: 12.5),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    ActionChip(
                                      label: const Text('Gestor'),
                                      onPressed: () => _preencherDemo(
                                        'gestor@agrocampo.app',
                                      ),
                                    ),
                                    ActionChip(
                                      label: const Text('Produtor'),
                                      onPressed: () => _preencherDemo(
                                        'produtor@agrocampo.app',
                                      ),
                                    ),
                                    ActionChip(
                                      label: const Text('Agrônomo'),
                                      onPressed: () => _preencherDemo(
                                        'agronomo@agrocampo.app',
                                      ),
                                    ),
                                    ActionChip(
                                      label: const Text('Técnico'),
                                      onPressed: () => _preencherDemo(
                                        'tecnico@agrocampo.app',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          'Conectado ao servidor remoto Supabase.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
