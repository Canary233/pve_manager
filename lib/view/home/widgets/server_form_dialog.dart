import 'package:flutter/material.dart';

import 'package:pve_manager/core/l10n/l10n_extensions.dart';
import 'package:pve_manager/data/models/pve_server_config.dart';
import 'package:pve_manager/core/utils/proxmox_url.dart';

class ServerFormDialog extends StatefulWidget {
  const ServerFormDialog({this.server, super.key});

  final PveServerConfig? server;

  @override
  State<ServerFormDialog> createState() => _ServerFormDialogState();
}

class _ServerFormDialogState extends State<ServerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _userController;
  late final TextEditingController _passwordController;
  late final TextEditingController _realmController;
  late bool _ignoreCertificateErrors;

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    _nameController = TextEditingController(text: server?.name ?? '');
    _hostController = TextEditingController(text: server?.origin ?? 'https://');
    _userController = TextEditingController(text: server?.username ?? 'root');
    _passwordController = TextEditingController(text: server?.password ?? '');
    _realmController = TextEditingController(text: server?.realm ?? 'pam');
    _ignoreCertificateErrors = server?.ignoreCertificateErrors ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _realmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final origin = normalizeOrigin(_hostController.text);
    final name = _nameController.text.trim().isEmpty
        ? Uri.parse(origin).host
        : _nameController.text.trim();

    Navigator.of(context).pop(
      PveServerConfig(
        name: name,
        origin: origin,
        username: _userController.text.trim(),
        password: _passwordController.text,
        realm: _realmController.text.trim(),
        ignoreCertificateErrors: _ignoreCertificateErrors,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editing = widget.server != null;

    return AlertDialog(
      title: Text(editing ? l10n.editServer : l10n.addServer),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.serverName,
                    hintText: l10n.serverNameHint,
                    prefixIcon: const Icon(Icons.label_rounded),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hostController,
                  decoration: InputDecoration(
                    labelText: l10n.proxmoxAddress,
                    hintText: 'https://192.168.1.10:8006',
                    prefixIcon: const Icon(Icons.dns_rounded),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  validator: (value) => validateOrigin(l10n, value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _userController,
                        decoration: InputDecoration(
                          labelText: l10n.username,
                          prefixIcon: const Icon(Icons.person_rounded),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            requiredField(value, l10n.enterUsername),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _realmController,
                        decoration: InputDecoration(labelText: l10n.realm),
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            requiredField(value, l10n.enterRealm),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    prefixIcon: const Icon(Icons.lock_rounded),
                  ),
                  obscureText: true,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) =>
                      requiredField(value, l10n.enterPassword),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.allowSelfSignedCertificate),
                  value: _ignoreCertificateErrors,
                  onChanged: (value) {
                    setState(() {
                      _ignoreCertificateErrors = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? l10n.save : l10n.add),
        ),
      ],
    );
  }
}
