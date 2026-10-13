import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/khataflow_repository.dart';

part 'parts/dashboard_page.dart';
part 'parts/parties_page.dart';
part 'parts/transactions_page.dart';
part 'parts/expenses_page.dart';
part 'parts/more_page.dart';

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
