part of '../business_home_screen.dart';

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({
    required this.repository,
    required this.business,
    required this.onOpenTab,
  });

  final KhataFlowRepository repository;
  final BusinessRecord business;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LedgerEntry>>(
      stream: repository.watchTransactions(business.id),
      builder: (context, transactionSnapshot) {
        if (transactionSnapshot.hasError) {
          return _PageError(
            message: _friendlyError(transactionSnapshot.error!),
          );
        }
        if (!transactionSnapshot.hasData) return const _LoadingState();
        final entries = transactionSnapshot.data!;
        final receivable = entries.fold<int>(0, (total, entry) {
          if (entry.kind == 'credit_given') return total + entry.amountMinor;
          if (entry.kind == 'payment_received') {
            return total - entry.amountMinor;
          }
          return total;
        });
        final payable = entries.fold<int>(0, (total, entry) {
          if (entry.kind == 'credit_taken') return total + entry.amountMinor;
          if (entry.kind == 'payment_made') return total - entry.amountMinor;
          return total;
        });

        return StreamBuilder<List<ExpenseRecord>>(
          stream: repository.watchExpenses(business.id),
          builder: (context, expenseSnapshot) {
            if (expenseSnapshot.hasError) {
              return _PageError(
                message: _friendlyError(expenseSnapshot.error!),
              );
            }
            if (!expenseSnapshot.hasData) return const _LoadingState();
            final expenses = expenseSnapshot.data!;
            final expenseTotal = expenses.fold<int>(
              0,
              (total, expense) => total + expense.amountMinor,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Text(
                  'Good ${_dayGreeting()},',
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  (FirebaseAuth.instance.currentUser?.displayName
                              ?.trim()
                              .isNotEmpty ??
                          false)
                      ? FirebaseAuth.instance.currentUser!.displayName!.trim()
                      : 'Welcome to your ledger',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${business.name} · ${business.type}',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 22),
                const _SectionHeading(title: 'Business summary'),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: width,
                          child: _MetricCard(
                            title: 'Customers owe',
                            value: formatMoney(receivable),
                            icon: Icons.call_made_rounded,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _MetricCard(
                            title: 'You owe suppliers',
                            value: formatMoney(payable),
                            icon: Icons.call_received_rounded,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _MetricCard(
                            title: 'Recorded expenses',
                            value: formatMoney(expenseTotal),
                            icon: Icons.payments_outlined,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _MetricCard(
                            title: 'Ledger entries',
                            value: entries.length.toString(),
                            icon: Icons.receipt_long_rounded,
                            color: _brand,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const _SectionHeading(title: 'Quick actions'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Add party',
                        onTap: () => onOpenTab(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.add_card_rounded,
                        label: 'Add entry',
                        onTap: () => onOpenTab(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.add_chart_rounded,
                        label: 'Add expense',
                        onTap: () => onOpenTab(3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _SectionHeading(title: 'KhataFlow smart tools'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE5F3EF),
                      child: Icon(Icons.insights_rounded, color: _brand),
                    ),
                    title: const Text(
                      'KhataFlow Pulse',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Collection trends, largest balances and expense signals',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => KhataFlowPulseScreen(
                          businessId: business.id,
                          businessName: business.name,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE5F3EF),
                      child: Icon(Icons.auto_awesome_rounded, color: _brand),
                    ),
                    title: const Text(
                      'Ask KhataFlow',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Ask questions by typing or speaking'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => KhataFlowAssistantScreen(
                          businessId: business.id,
                          businessName: business.name,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeading(
                  title: 'Recent activity',
                  trailing: TextButton(
                    onPressed: () => onOpenTab(2),
                    child: const Text('View ledger'),
                  ),
                ),
                const SizedBox(height: 4),
                if (entries.isEmpty)
                  const _EmptyInline(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet',
                    message: 'Record your first credit or payment to begin.',
                  )
                else
                  ...entries.take(5).map((entry) => _EntryTile(entry: entry)),
              ],
            );
          },
        );
      },
    );
  }
}

String _dayGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  return 'evening';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 135),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 13),
          Text(title, style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _brand, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = transactionColor(entry.kind);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(transactionIcon(entry.kind), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.partyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${transactionLabel(entry.kind)} · ${formatDate(entry.occurredAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                if (entry.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoney(entry.amountMinor),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
