import 'package:flutter/material.dart';

import 'package:pve_manager/core/l10n/l10n_extensions.dart';
import 'package:pve_manager/data/models/pve_resource.dart';
import 'package:pve_manager/core/widgets/empty_state.dart';
import 'package:pve_manager/core/widgets/status_pill.dart';

class GuestPanel extends StatelessWidget {
  const GuestPanel({
    required this.guests,
    required this.onSelect,
    this.selectedGuestId,
    super.key,
  });

  final List<PveResource> guests;
  final ValueChanged<PveResource> onSelect;
  final String? selectedGuestId;

  @override
  Widget build(BuildContext context) {
    if (guests.isEmpty) {
      return EmptyState(text: context.l10n.noGuests);
    }

    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: guests.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final guest = guests[index];
          final selected = guest.id == selectedGuestId;
          return ListTile(
            selected: selected,
            selectedTileColor: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.42),
            leading: CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              child: Icon(
                guest.type == 'qemu'
                    ? Icons.desktop_windows_rounded
                    : Icons.inventory_2_rounded,
              ),
            ),
            title: Text(guest.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${localizedResourceType(context.l10n, guest.type)} '
              '${guest.vmid} · ${guest.node}',
            ),
            trailing: StatusPill(status: guest.status),
            onTap: () => onSelect(guest),
          );
        },
      ),
    );
  }
}
