import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/khataflow_repository.dart';

const Color _brand = Color(0xFF176B5B);
const Color _ink = Color(0xFF172B2A);
const Color _muted = Color(0xFF64748B);
const Color _line = Color(0xFFE5EAF0);
const List<String> _businessTypes = [
  'General',
  'Retail shop',
  'Wholesale',
  'Services',
  'Manufacturing',
  'Other',
];
const List<String> _expenseCategories = [
  'Stock / Purchases',
  'Rent',
  'Utilities',
  'Salaries',
  'Transport',
  'Marketing',
  'Maintenance',
  'Other',
];

String formatMoney(int amountMinor) {
  final isNegative = amountMinor < 0;
  final absoluteAmount = amountMinor.abs();
  final rupees = absoluteAmount ~/ 100;
  final paisa = (absoluteAmount % 100).toString().padLeft(2, '0');
  final digits = rupees.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return '${isNegative ? '-' : ''}Rs $grouped.$paisa';
}

int? parseAmountMinor(String value) {
  final normalized = value.trim().replaceAll(',', '');
  final amount = double.tryParse(normalized);
  if (amount == null || !amount.isFinite || amount <= 0) return null;
  if (amount > 999999999999) return null;
  return (amount * 100).round();
}

String formatDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String partyTypeLabel(String type) => switch (type) {
  'customer' => 'Customer',
  'supplier' => 'Supplier',
  'both' => 'Customer & supplier',
  _ => 'Customer',
};

String transactionLabel(String kind) => switch (kind) {
  'credit_given' => 'Credit given',
  'payment_received' => 'Payment received',
  'credit_taken' => 'Credit taken',
  'payment_made' => 'Payment made',
  _ => 'Transaction',
};

IconData transactionIcon(String kind) => switch (kind) {
  'credit_given' => Icons.call_made_rounded,
  'payment_received' => Icons.south_west_rounded,
  'credit_taken' => Icons.call_received_rounded,
  'payment_made' => Icons.north_east_rounded,
  _ => Icons.swap_horiz_rounded,
};

Color transactionColor(String kind) => switch (kind) {
  'credit_given' => const Color(0xFFB45309),
  'payment_received' => const Color(0xFF15803D),
  'credit_taken' => const Color(0xFF7C3AED),
  'payment_made' => const Color(0xFF2563EB),
  _ => _muted,
};

/// Authenticated KhataFlow workspace. This replaces the previous placeholder home.
class BusinessHomeScreen extends StatefulWidget {
  const BusinessHomeScreen({super.key, required this.user});

  final User user;

  @override
  State<BusinessHomeScreen> createState() => _BusinessHomeScreenState();
}

class _BusinessHomeScreenState extends State<BusinessHomeScreen> {
  late final KhataFlowRepository _repository;
  String? _selectedBusinessId;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _repository = KhataFlowRepository(userId: widget.user.uid);
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.red.shade700 : _brand,
        ),
      );
  }

  Future<void> _createBusiness() async {
    final draft = await showDialog<_BusinessDraft>(
      context: context,
      builder: (_) => const _BusinessFormDialog(),
    );
    if (draft == null) return;

    try {
      final id = await _repository.createBusiness(
        name: draft.name,
        type: draft.type,
      );
      if (!mounted) return;
      setState(() {
        _selectedBusinessId = id;
        _selectedTab = 0;
      });
      _showMessage('${draft.name.trim()} is ready.');
    } catch (error) {
      _showMessage(_friendlyError(error), isError: true);
    }
  }

  void _selectBusiness(String businessId) {
    setState(() {
      _selectedBusinessId = businessId;
      _selectedTab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BusinessRecord>>(
      stream: _repository.watchBusinesses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: _MessageState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load businesses',
              message: _friendlyError(snapshot.error!),
              actionLabel: 'Try again',
              onAction: () => setState(() {}),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: _LoadingState());
        }

        final businesses = snapshot.data!;
        if (businesses.isEmpty) {
          return Scaffold(
            body: _NoBusinessState(onCreateBusiness: _createBusiness),
          );
        }

        BusinessRecord active;
        final selected = businesses.where((b) => b.id == _selectedBusinessId);
        active = selected.isNotEmpty ? selected.first : businesses.first;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: PopupMenuButton<String>(
              tooltip: 'Switch business',
              onSelected: _selectBusiness,
              itemBuilder: (context) => businesses
                  .map(
                    (business) => PopupMenuItem<String>(
                      value: business.id,
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_outlined, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(business.name)),
                          if (business.id == active.id)
                            const Icon(Icons.check_rounded, color: _brand),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _brand.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: _brand,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'KhataFlow',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          active.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _muted,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Add business',
                onPressed: _createBusiness,
                icon: const Icon(Icons.add_business_outlined),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: IndexedStack(
            index: _selectedTab,
            children: [
              _OverviewPage(
                repository: _repository,
                business: active,
                onOpenTab: (index) => setState(() => _selectedTab = index),
              ),
              _PartiesPage(repository: _repository, business: active),
              _TransactionsPage(repository: _repository, business: active),
              _ExpensesPage(repository: _repository, business: active),
              _MorePage(
                user: widget.user,
                businesses: businesses,
                activeBusiness: active,
                onSelectBusiness: _selectBusiness,
                onCreateBusiness: _createBusiness,
                onSignOut: () async {
                  try {
                    await FirebaseAuth.instance.signOut();
                  } catch (error) {
                    _showMessage(_friendlyError(error), isError: true);
                  }
                },
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) =>
                setState(() => _selectedTab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard_rounded),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Parties',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Ledger',
              ),
              NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments_rounded),
                label: 'Expenses',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_horiz_rounded),
                selectedIcon: Icon(Icons.more_horiz_rounded),
                label: 'More',
              ),
            ],
          ),
        );
      },
    );
  }
}

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

class _PartiesPage extends StatefulWidget {
  const _PartiesPage({required this.repository, required this.business});

  final KhataFlowRepository repository;
  final BusinessRecord business;

  @override
  State<_PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<_PartiesPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editParty({PartyRecord? party}) async {
    final draft = await showDialog<_PartyDraft>(
      context: context,
      builder: (_) => _PartyFormDialog(party: party),
    );
    if (draft == null) return;
    try {
      await widget.repository.saveParty(
        businessId: widget.business.id,
        partyId: party?.id,
        name: draft.name,
        phone: draft.phone,
        type: draft.type,
        notes: draft.notes,
      );
      if (!mounted) return;
      _message(context, party == null ? 'Party added.' : 'Party updated.');
    } catch (error) {
      if (mounted) _message(context, _friendlyError(error), isError: true);
    }
  }

  void _showPartyDetails(PartyRecord party) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  party.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${partyTypeLabel(party.type)}${party.phone.isEmpty ? '' : ' · ${party.phone}'}',
                  style: const TextStyle(color: _muted),
                ),
                if (party.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(party.notes),
                ],
                const SizedBox(height: 18),
                const _SectionHeading(title: 'Transaction history'),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<List<LedgerEntry>>(
                    stream: widget.repository.watchTransactions(
                      widget.business.id,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _PageError(
                          message: _friendlyError(snapshot.error!),
                        );
                      }
                      if (!snapshot.hasData) return const _LoadingState();
                      final entries = snapshot.data!
                          .where((entry) => entry.partyId == party.id)
                          .toList();
                      if (entries.isEmpty) {
                        return const _EmptyInline(
                          icon: Icons.receipt_long_outlined,
                          title: 'No activity yet',
                          message:
                              'Transactions for this party will appear here.',
                        );
                      }
                      return ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) =>
                            _EntryTile(entry: entries[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PartyRecord>>(
      stream: widget.repository.watchParties(widget.business.id),
      builder: (context, partySnapshot) {
        if (partySnapshot.hasError) {
          return _PageError(message: _friendlyError(partySnapshot.error!));
        }
        if (!partySnapshot.hasData) return const _LoadingState();
        final allParties = partySnapshot.data!;
        final parties = allParties.where((party) {
          final query = _query.toLowerCase();
          return party.name.toLowerCase().contains(query) ||
              party.phone.toLowerCase().contains(query);
        }).toList();

        return StreamBuilder<List<LedgerEntry>>(
          stream: widget.repository.watchTransactions(widget.business.id),
          builder: (context, transactionSnapshot) {
            final entries = transactionSnapshot.data ?? const <LedgerEntry>[];
            return Scaffold(
              backgroundColor: Colors.transparent,
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _editParty(),
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add party'),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
                children: [
                  const Text(
                    'Customers & suppliers',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Keep every business contact and balance together.',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search by name or phone',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _TinyCountCard(
                          label: 'All parties',
                          value: allParties.length,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TinyCountCard(
                          label: 'Customers',
                          value: allParties
                              .where(
                                (p) => p.type == 'customer' || p.type == 'both',
                              )
                              .length,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TinyCountCard(
                          label: 'Suppliers',
                          value: allParties
                              .where(
                                (p) => p.type == 'supplier' || p.type == 'both',
                              )
                              .length,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (parties.isEmpty)
                    _EmptyInline(
                      icon: Icons.people_outline_rounded,
                      title: _query.isEmpty
                          ? 'No parties added'
                          : 'No matches found',
                      message: _query.isEmpty
                          ? 'Add your first customer or supplier to start keeping records.'
                          : 'Try another name or phone number.',
                      actionLabel: _query.isEmpty
                          ? 'Add your first party'
                          : null,
                      onAction: _query.isEmpty ? () => _editParty() : null,
                    )
                  else
                    ...parties.map(
                      (party) => _PartyTile(
                        party: party,
                        balanceLabel: _partyBalanceLabel(party, entries),
                        onTap: () => _showPartyDetails(party),
                        onEdit: () => _editParty(party: party),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

String _partyBalanceLabel(PartyRecord party, List<LedgerEntry> entries) {
  final related = entries.where((entry) => entry.partyId == party.id);
  var receivable = 0;
  var payable = 0;
  for (final entry in related) {
    switch (entry.kind) {
      case 'credit_given':
        receivable += entry.amountMinor;
        break;
      case 'payment_received':
        receivable -= entry.amountMinor;
        break;
      case 'credit_taken':
        payable += entry.amountMinor;
        break;
      case 'payment_made':
        payable -= entry.amountMinor;
        break;
    }
  }

  if (party.type == 'supplier') {
    return payable >= 0
        ? 'You owe ${formatMoney(payable)}'
        : 'Advance ${formatMoney(payable.abs())}';
  }
  if (party.type == 'both') {
    return 'Owed ${formatMoney(receivable)} · Payable ${formatMoney(payable)}';
  }
  return receivable >= 0
      ? 'Owed ${formatMoney(receivable)}'
      : 'Advance ${formatMoney(receivable.abs())}';
}

class _PartyTile extends StatelessWidget {
  const _PartyTile({
    required this.party,
    required this.balanceLabel,
    required this.onTap,
    required this.onEdit,
  });

  final PartyRecord party;
  final String balanceLabel;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final letter = party.name.trim().isEmpty
        ? '?'
        : party.name.trim()[0].toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(14, 7, 5, 7),
        leading: CircleAvatar(
          backgroundColor: _brand.withValues(alpha: 0.10),
          foregroundColor: _brand,
          child: Text(
            letter,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          party.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${partyTypeLabel(party.type)}${party.phone.isEmpty ? '' : ' · ${party.phone}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                balanceLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _brand,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          onPressed: onEdit,
          tooltip: 'Edit party',
          icon: const Icon(Icons.edit_outlined, size: 20),
        ),
      ),
    );
  }
}

class _TinyCountCard extends StatelessWidget {
  const _TinyCountCard({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PartyDraft {
  const _PartyDraft({
    required this.name,
    required this.phone,
    required this.type,
    required this.notes,
  });

  final String name;
  final String phone;
  final String type;
  final String notes;
}

class _PartyFormDialog extends StatefulWidget {
  const _PartyFormDialog({this.party});
  final PartyRecord? party;

  @override
  State<_PartyFormDialog> createState() => _PartyFormDialogState();
}

class _PartyFormDialogState extends State<_PartyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _notes;
  late String _type;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.party?.name ?? '');
    _phone = TextEditingController(text: widget.party?.phone ?? '');
    _notes = TextEditingController(text: widget.party?.notes ?? '');
    _type = widget.party?.type ?? 'customer';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.party == null ? 'Add party' : 'Edit party'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Party type'),
                items: const [
                  DropdownMenuItem(value: 'customer', child: Text('Customer')),
                  DropdownMenuItem(value: 'supplier', child: Text('Supplier')),
                  DropdownMenuItem(value: 'both', child: Text('Both')),
                ],
                onChanged: (value) =>
                    setState(() => _type = value ?? 'customer'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _PartyDraft(
                name: _name.text.trim(),
                phone: _phone.text.trim(),
                type: _type,
                notes: _notes.text.trim(),
              ),
            );
          },
          child: const Text('Save party'),
        ),
      ],
    );
  }
}

class _TransactionDraft {
  const _TransactionDraft({
    required this.party,
    required this.kind,
    required this.amountMinor,
    required this.description,
  });

  final PartyRecord party;
  final String kind;
  final int amountMinor;
  final String description;
}

class _TransactionsPage extends StatefulWidget {
  const _TransactionsPage({required this.repository, required this.business});

  final KhataFlowRepository repository;
  final BusinessRecord business;

  @override
  State<_TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<_TransactionsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addEntry(List<PartyRecord> parties) async {
    if (parties.isEmpty) {
      _message(
        context,
        'Add a customer or supplier before recording a transaction.',
        isError: true,
      );
      return;
    }
    final draft = await showDialog<_TransactionDraft>(
      context: context,
      builder: (_) => _TransactionFormDialog(parties: parties),
    );
    if (draft == null) return;
    try {
      await widget.repository.addTransaction(
        businessId: widget.business.id,
        party: draft.party,
        kind: draft.kind,
        amountMinor: draft.amountMinor,
        description: draft.description,
      );
      if (mounted) _message(context, 'Transaction recorded.');
    } catch (error) {
      if (mounted) _message(context, _friendlyError(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PartyRecord>>(
      stream: widget.repository.watchParties(widget.business.id),
      builder: (context, partySnapshot) {
        final parties = partySnapshot.data ?? const <PartyRecord>[];
        return StreamBuilder<List<LedgerEntry>>(
          stream: widget.repository.watchTransactions(widget.business.id),
          builder: (context, entrySnapshot) {
            if (entrySnapshot.hasError) {
              return _PageError(message: _friendlyError(entrySnapshot.error!));
            }
            if (!entrySnapshot.hasData) return const _LoadingState();
            final entries = entrySnapshot.data!;
            final filtered = entries.where((entry) {
              final query = _query.toLowerCase();
              return entry.partyName.toLowerCase().contains(query) ||
                  entry.description.toLowerCase().contains(query) ||
                  transactionLabel(entry.kind).toLowerCase().contains(query);
            }).toList();
            final totalEntries = entries.length;

            return Scaffold(
              backgroundColor: Colors.transparent,
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _addEntry(parties),
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Record entry'),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
                children: [
                  const Text(
                    'Transaction ledger',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Credits and payments are recorded as separate entries.',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search party, type, or note',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TinyCountCard(
                    label: 'Total ledger entries',
                    value: totalEntries,
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    _EmptyInline(
                      icon: Icons.receipt_long_outlined,
                      title: _query.isEmpty
                          ? 'No transactions yet'
                          : 'No matches found',
                      message: _query.isEmpty
                          ? 'Record credit given, payments received, credit taken, or payments made.'
                          : 'Try a different search.',
                      actionLabel: _query.isEmpty ? 'Record first entry' : null,
                      onAction: _query.isEmpty && parties.isNotEmpty
                          ? () => _addEntry(parties)
                          : null,
                    )
                  else
                    ...filtered.map((entry) => _EntryTile(entry: entry)),
                  if (partySnapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Party list error: ${_friendlyError(partySnapshot.error!)}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

List<String> _allowedKindsFor(PartyRecord party) {
  if (party.type == 'supplier') return const ['credit_taken', 'payment_made'];
  if (party.type == 'both') {
    return const [
      'credit_given',
      'payment_received',
      'credit_taken',
      'payment_made',
    ];
  }
  return const ['credit_given', 'payment_received'];
}

class _TransactionFormDialog extends StatefulWidget {
  const _TransactionFormDialog({required this.parties});
  final List<PartyRecord> parties;

  @override
  State<_TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<_TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _partyId;
  late String _kind;

  PartyRecord get _selectedParty =>
      widget.parties.firstWhere((party) => party.id == _partyId);

  @override
  void initState() {
    super.initState();
    _partyId = widget.parties.first.id;
    _kind = _allowedKindsFor(_selectedParty).first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableKinds = _allowedKindsFor(_selectedParty);
    if (!availableKinds.contains(_kind)) _kind = availableKinds.first;

    return AlertDialog(
      title: const Text('Record transaction'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _partyId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Customer / supplier',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: widget.parties
                    .map(
                      (party) => DropdownMenuItem(
                        value: party.id,
                        child: Text(
                          party.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _partyId = value;
                    final allowed = _allowedKindsFor(_selectedParty);
                    if (!allowed.contains(_kind)) _kind = allowed.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Transaction type',
                  prefixIcon: Icon(Icons.swap_horiz_rounded),
                ),
                items: availableKinds
                    .map(
                      (kind) => DropdownMenuItem(
                        value: kind,
                        child: Text(transactionLabel(kind)),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _kind = value ?? availableKinds.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (Rs) *',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.currency_exchange_rounded),
                ),
                validator: (value) => parseAmountMinor(value ?? '') == null
                    ? 'Enter an amount greater than zero.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'A partial payment should be added as a new entry.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _TransactionDraft(
                party: _selectedParty,
                kind: _kind,
                amountMinor: parseAmountMinor(_amountController.text)!,
                description: _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Save entry'),
        ),
      ],
    );
  }
}

class _ExpensesPage extends StatefulWidget {
  const _ExpensesPage({required this.repository, required this.business});

  final KhataFlowRepository repository;
  final BusinessRecord business;

  @override
  State<_ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<_ExpensesPage> {
  Future<void> _addExpense() async {
    final draft = await showDialog<_ExpenseDraft>(
      context: context,
      builder: (_) => const _ExpenseFormDialog(),
    );
    if (draft == null) return;
    try {
      await widget.repository.addExpense(
        businessId: widget.business.id,
        amountMinor: draft.amountMinor,
        category: draft.category,
        description: draft.description,
      );
      if (mounted) _message(context, 'Expense saved.');
    } catch (error) {
      if (mounted) _message(context, _friendlyError(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExpenseRecord>>(
      stream: widget.repository.watchExpenses(widget.business.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _PageError(message: _friendlyError(snapshot.error!));
        }
        if (!snapshot.hasData) return const _LoadingState();
        final expenses = snapshot.data!;
        final total = expenses.fold<int>(
          0,
          (sum, item) => sum + item.amountMinor,
        );

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addExpense,
            backgroundColor: _brand,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add expense'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
            children: [
              const Text(
                'Business expenses',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Keep operational spending visible and organized.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _brand,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Total recorded expenses',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatMoney(total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${expenses.length} expense record(s)',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _SectionHeading(title: 'Expense history'),
              const SizedBox(height: 12),
              if (expenses.isEmpty)
                _EmptyInline(
                  icon: Icons.receipt_outlined,
                  title: 'No expenses recorded',
                  message:
                      'Add rent, purchases, utilities, and other business costs here.',
                  actionLabel: 'Add first expense',
                  onAction: _addExpense,
                )
              else
                ...expenses.map((expense) => _ExpenseTile(expense: expense)),
            ],
          ),
        );
      },
    );
  }
}

class _ExpenseDraft {
  const _ExpenseDraft({
    required this.amountMinor,
    required this.category,
    required this.description,
  });
  final int amountMinor;
  final String category;
  final String description;
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog();

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = _expenseCategories.first;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add expense'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (Rs) *',
                  prefixIcon: Icon(Icons.currency_exchange_rounded),
                  hintText: '0.00',
                ),
                validator: (value) => parseAmountMinor(value ?? '') == null
                    ? 'Enter an amount greater than zero.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _expenseCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(
                  () => _category = value ?? _expenseCategories.first,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _ExpenseDraft(
                amountMinor: parseAmountMinor(_amountController.text)!,
                category: _category,
                description: _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Save expense'),
        ),
      ],
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});
  final ExpenseRecord expense;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.category,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatDate(expense.occurredAt)}${expense.description.isEmpty ? '' : ' · ${expense.description}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoney(expense.amountMinor),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _ink,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MorePage extends StatelessWidget {
  const _MorePage({
    required this.user,
    required this.businesses,
    required this.activeBusiness,
    required this.onSelectBusiness,
    required this.onCreateBusiness,
    required this.onSignOut,
  });

  final User user;
  final List<BusinessRecord> businesses;
  final BusinessRecord activeBusiness;
  final ValueChanged<String> onSelectBusiness;
  final VoidCallback onCreateBusiness;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        const Text(
          'More & settings',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Manage your workspace and account.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: _brand.withValues(alpha: 0.10),
                foregroundColor: _brand,
                child: const Icon(Icons.person_rounded, size: 27),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user.displayName?.trim().isNotEmpty ?? false)
                          ? user.displayName!.trim()
                          : 'KhataFlow user',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email ?? 'No email available',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: _SectionHeading(title: 'Your businesses')),
            TextButton.icon(
              onPressed: onCreateBusiness,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...businesses.map((business) {
          final isActive = business.id == activeBusiness.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: isActive ? _brand : _line),
              borderRadius: BorderRadius.circular(17),
            ),
            child: ListTile(
              onTap: () => onSelectBusiness(business.id),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.storefront_outlined, color: _brand),
              ),
              title: Text(
                business.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${business.type} · ${business.currencyCode}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              trailing: isActive
                  ? const Icon(Icons.check_circle_rounded, color: _brand)
                  : const Icon(Icons.chevron_right_rounded),
            ),
          );
        }),
        const SizedBox(height: 14),
        const _SectionHeading(title: 'Data & account'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_done_outlined, color: _brand),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cloud sync through Firestore',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Business records, parties, transactions, and expenses are stored under the selected business. Make sure Firestore security rules are published before using real business information.',
                style: TextStyle(color: _muted, height: 1.4, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade200),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'KhataFlow · Business ledger',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _BusinessDraft {
  const _BusinessDraft({required this.name, required this.type});
  final String name;
  final String type;
}

class _BusinessFormDialog extends StatefulWidget {
  const _BusinessFormDialog();

  @override
  State<_BusinessFormDialog> createState() => _BusinessFormDialogState();
}

class _BusinessFormDialogState extends State<_BusinessFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _type = _businessTypes.first;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create a business'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Business name *',
                prefixIcon: Icon(Icons.storefront_outlined),
                hintText: 'e.g. Hanan Traders',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a business name.'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Business type',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _businessTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? 'General'),
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Currency: Pakistani Rupee (PKR)',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _BusinessDraft(name: _nameController.text.trim(), type: _type),
            );
          },
          child: const Text('Create business'),
        ),
      ],
    );
  }
}

class _NoBusinessState extends StatelessWidget {
  const _NoBusinessState({required this.onCreateBusiness});
  final VoidCallback onCreateBusiness;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _brand.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.store_mall_directory_outlined,
                    size: 46,
                    color: _brand,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Set up your first business',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Create a workspace to start adding customers, suppliers, transactions, and expenses. You can create and switch between multiple businesses later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onCreateBusiness,
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('Create my business'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: CircularProgressIndicator(color: _brand),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: _muted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => _MessageState(
    icon: Icons.cloud_off_outlined,
    title: 'Could not load this data',
    message: message,
  );
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: _brand, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _ink,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.4, fontSize: 12),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 15),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

String _friendlyError(Object error) {
  final value = error.toString();
  if (value.contains('permission-denied') ||
      value.contains('PERMISSION_DENIED')) {
    return 'Firestore denied this request. Check that your Firestore database exists and its security rules allow this signed-in user to access the selected business.';
  }
  if (value.contains('unavailable') || value.contains('UNAVAILABLE')) {
    return 'The database is temporarily unavailable. Check your internet connection and try again.';
  }
  if (value.contains('network')) {
    return 'Network error. Check your internet connection and try again.';
  }
  return value.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
}

void _message(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : _brand,
      ),
    );
}
