import 'package:flutter/material.dart';

import 'design/brand_mark.dart';
import 'design/components/components.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'session.dart';

/// P13：任务标题常量同时供导航栏与正文 title2 使用。
const _setupTitle = '初始化站点';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.session});
  final SessionController session;
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!_form.currentState!.validate()) return;
    final value = _password.text;
    _password.clear();
    _confirmation.clear();
    final finished = await widget.session.initialize(value);
    if (mounted && finished) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final session = widget.session;
      return PopScope(
        canPop: !session.loading,
        child: Scaffold(
          appBar: mileafPageBar(context, title: const Text(_setupTitle)),
          body: SafeArea(
            child: MileafContent(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(MileafLayout.pageInset(context)),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: MileafWordmark(markSize: 32),
                      ),
                      const SizedBox(height: MileafSpace.s16),
                      // P13：任务标题 title2。
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_setupTitle, style: context.type.title2),
                      ),
                      const SizedBox(height: MileafSpace.s8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          session.site!.uri.toString(),
                          style: context.type.subheadline.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: MileafSpace.s4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '仅适用于尚未设置访问口令的站点。已有站点请返回登录。',
                          style: context.type.body.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: MileafSpace.s24),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        enabled: !session.loading,
                        decoration: const InputDecoration(
                          labelText: '新站点口令',
                          errorMaxLines: 4,
                        ),
                        validator: (value) => (value?.runes.length ?? 0) < 10
                            ? '口令至少需要 10 个字符'
                            : null,
                      ),
                      const SizedBox(height: MileafSpace.s16),
                      TextFormField(
                        controller: _confirmation,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        enabled: !session.loading,
                        decoration: const InputDecoration(
                          labelText: '再次输入口令',
                          errorMaxLines: 4,
                        ),
                        validator: (value) =>
                            value != _password.text ? '两次输入的口令不一致' : null,
                      ),
                      const SizedBox(height: MileafSpace.s24),
                      // R27：主按钮胶囊；处理中保留文字并在尾部加活动指示器。
                      MileafButton(
                        label: '设置口令并登录',
                        expand: true,
                        loading: session.loading,
                        onPressed: session.canLogin ? _initialize : null,
                      ),
                      const SizedBox(height: MileafSpace.s8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: MileafButton(
                          label: '返回登录',
                          kind: MileafButtonKind.ghost,
                          onPressed: session.loading
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ),
                      if (session.message != null)
                        Padding(
                          padding: const EdgeInsets.only(top: MileafSpace.s16),
                          child: Semantics(
                            liveRegion: true,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                session.message!,
                                style: context.type.body.copyWith(
                                  color: context.colors.error,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
