import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../core/graph.dart';
import '../../core/strings.dart';
import '../../services/portal/portal_endpoints.dart';
import '../../ui/appbar/sys_app_bar.dart';
import '../../ui/card/tonal_card.dart';

/// 统一身份认证登录。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _graph = AppGraph.instance;

  late final TextEditingController _username =
      TextEditingController(text: _graph.auth.lastUsername);
  final _password = TextEditingController();
  final _captcha = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _captcha.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty) {
      _toast(S.usernameEmpty);
      return;
    }
    if (password.isEmpty) {
      _toast(S.passwordEmpty);
      return;
    }

    final ok = await _graph.auth.login(
      username: username,
      password: password,
      captchaCode: _captcha.text.trim().isEmpty ? null : _captcha.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      _graph.home.refresh();
      _toast(S.loginSuccess);
      context.pop();
    }
  }

  void _webLogin() {
    _graph.navArgs.openUrl(
      PortalEndpoints.loginUrl,
      S.loginTitle,
      adopt: true,
    );
    context.pushNamed('/webview');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = _graph.auth;

    return Scaffold(
      appBar: SysAppBar(
        title: S.loginTitle,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Observer(
        builder: (_) {
          final busy = auth.loggingIn.value;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              TonalCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        S.loginSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TonalCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _username,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: S.username,
                        hintText: S.usernameHint,
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      enabled: !busy,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: S.password,
                        hintText: S.passwordHint,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    if (auth.needCaptcha.value) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _captcha,
                              enabled: !busy,
                              decoration: const InputDecoration(
                                labelText: S.captcha,
                                hintText: S.captchaHint,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () async {
                              final bytes = await _graph.cas.captchaImage();
                              auth.captcha.value = bytes;
                            },
                            child: Container(
                              width: 92,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: auth.captcha.value == null
                                  ? const Icon(Icons.refresh_rounded, size: 18)
                                  : Image.memory(
                                      auth.captcha.value!,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (auth.error.value != null) ...[
                const SizedBox(height: 12),
                Text(
                  auth.error.value!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : _submit,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(S.loginAction),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: busy ? null : _webLogin,
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: const Text(S.webLoginFallback),
              ),
              const SizedBox(height: 8),
              Text(
                S.webLoginTip,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
