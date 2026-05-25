import 'package:flutter/material.dart';

import 'package:pve_manager/core/l10n/l10n_extensions.dart';
import 'package:pve_manager/data/models/pve_node.dart';
import 'package:pve_manager/core/utils/formatters.dart';
import 'package:pve_manager/core/widgets/empty_state.dart';
import 'package:pve_manager/core/widgets/status_pill.dart';
import 'package:pve_manager/core/widgets/usage_line.dart';

class NodeGrid extends StatelessWidget {
  const NodeGrid({
    required this.nodes,
    required this.onNodeTap,
    this.selectedNodeName,
    super.key,
  });

  final List<PveNode> nodes;
  final ValueChanged<PveNode> onNodeTap;
  final String? selectedNodeName;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return EmptyState(text: context.l10n.noNodes);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = nodes.length > 1 && constraints.maxWidth >= 760 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 132,
          ),
          itemCount: nodes.length,
          itemBuilder: (context, index) => _NodeCard(
            node: nodes[index],
            selected: nodes[index].name == selectedNodeName,
            onTap: () => onNodeTap(nodes[index]),
          ),
        );
      },
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final PveNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.48)
          : Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      node.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusPill(status: node.status),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const Spacer(),
              UsageLine(label: 'CPU', value: node.cpu, text: percent(node.cpu)),
              const SizedBox(height: 10),
              UsageLine(
                label: context.l10n.memory,
                value: node.memoryRatio,
                text: '${bytes(node.memoryUsed)} / ${bytes(node.memoryTotal)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
