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
  static const _realmOptions = ['pam', 'pve'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _userController;
  late final TextEditingController _passwordController;
  late String _realm;
  late bool _ignoreCertificateErrors;

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    _nameController = TextEditingController(text: server?.name ?? '');
    _hostController = TextEditingController(text: server?.origin ?? 'https://');
    _userController = TextEditingController(text: server?.username ?? 'root');
    _passwordController = TextEditingController(text: server?.password ?? '');
    _realm = _realmOptions.contains(server?.realm) ? server!.realm : 'pam';
    _ignoreCertificateErrors = server?.ignoreCertificateErrors ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _userController.dispose();
    _passwordController.dispose();
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
        realm: _realm,
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final realmWidth = constraints.maxWidth < 360 ? 92.0 : 96.0;
                    return Row(
                      children: [
                        Expanded(
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
                        SizedBox(
                          width: realmWidth,
                          child: _RealmSelector(
                            label: l10n.realm,
                            value: _realm,
                            options: _realmOptions,
                            onChanged: (value) {
                              setState(() {
                                _realm = value;
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
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

class _RealmSelector extends StatelessWidget {
  const _RealmSelector({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopupMenuButton<String>(
      tooltip: label,
      initialValue: value,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: onChanged,
      itemBuilder: (context) {
        return options.map((option) {
          final selected = option == value;
          return PopupMenuItem<String>(
            value: option,
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 20,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  option,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: selected ? colorScheme.primary : null,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
        ),
        child: SizedBox(
          height: 24,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
