import 'package:flutter/material.dart';

import '../../data/khataflow_repository.dart';

class KhataFlowPulseScreen extends StatelessWidget {
  const KhataFlowPulseScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  final String businessId;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    final repository = KhataFlowRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('KhataFlow Pulse')),
      body: StreamBuilder<List<LedgerEntry>>(
        stream: repository.watchTransactions(businessId),
        builder: (context, txSnapshot) {
          if (txSnapshot.hasError)
            return const _PulseState(
              title: 'Insights unavailable',
              message:
                  'Could not load the ledger. Check your connection and try again.',
            );
          if (!txSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return StreamBuilder<List<ExpenseRecord>>(
            stream: repository.watchExpenses(businessId),
            builder: (context, expenseSnapshot) {
              if (expenseSnapshot.hasError)
                return const _PulseState(
                  title: 'Expenses unavailable',
                  message: 'Could not load expense records.',
                );
              if (!expenseSnapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final entries = txSnapshot.data!;
              final expenses = expenseSnapshot.data!;
              final now = DateTime.now();
              final thisPeriod = now.subtract(const Duration(days: 30));
              final previousPeriod = now.subtract(const Duration(days: 60));
              var receivable = 0;
              var payable = 0;
              var collectionsNow = 0;
              var collectionsPrevious = 0;
              final debtors = <String, int>{};
              final creditors = <String, int>{};
              for (final entry in entries) {
                switch (entry.kind) {
                  case 'credit_given':
                    receivable += entry.amountMinor;
                    debtors.update(
                      entry.partyName,
                      (v) => v + entry.amountMinor,
                      ifAbsent: () => entry.amountMinor,
                    );
                    break;
                  case 'payment_received':
                    receivable -= entry.amountMinor;
                    debtors.update(
                      entry.partyName,
                      (v) => v - entry.amountMinor,
                      ifAbsent: () => -entry.amountMinor,
                    );
                    if (!entry.occurredAt.isBefore(thisPeriod) &&
                        !entry.occurredAt.isAfter(now)) {
                      collectionsNow += entry.amountMinor;
                    } else if (!entry.occurredAt.isBefore(previousPeriod) &&
                        entry.occurredAt.isBefore(thisPeriod)) {
                      collectionsPrevious += entry.amountMinor;
                    }
                    break;
                  case 'credit_taken':
                    payable += entry.amountMinor;
                    creditors.update(
                      entry.partyName,
                      (v) => v + entry.amountMinor,
                      ifAbsent: () => entry.amountMinor,
                    );
                    break;
                  case 'payment_made':
                    payable -= entry.amountMinor;
                    creditors.update(
                      entry.partyName,
                      (v) => v - entry.amountMinor,
                      ifAbsent: () => -entry.amountMinor,
                    );
                    break;
                }
              }
              final totalExpenses = expenses.fold<int>(
                0,
                (sum, item) => sum + item.amountMinor,
              );
              final categories = <String, int>{};
              for (final item in expenses) {
                categories.update(
                  item.category,
                  (v) => v + item.amountMinor,
                  ifAbsent: () => item.amountMinor,
                );
              }
              final topDebtors =
                  debtors.entries.where((e) => e.value > 0).toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
              final topCreditors =
                  creditors.entries.where((e) => e.value > 0).toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
              final topCategories = categories.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final change = collectionsPrevious == 0
                  ? null
                  : ((collectionsNow - collectionsPrevious) /
                            collectionsPrevious *
                            100)
                        .round();
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  Text(
                    businessName,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your business at a glance',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Explainable signals calculated from your saved ledger. No due dates are assumed.',
                    style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  _PulseMetric(
                    title: 'Customers owe you',
                    value: _pulseMoney(receivable),
                    icon: Icons.call_made_rounded,
                    color: const Color(0xFFB45309),
                  ),
                  _PulseMetric(
                    title: 'You owe suppliers',
                    value: _pulseMoney(payable),
                    icon: Icons.call_received_rounded,
                    color: const Color(0xFF7C3AED),
                  ),
                  _PulseMetric(
                    title: 'Collected in the last 30 days',
                    value: _pulseMoney(collectionsNow),
                    icon: Icons.south_west_rounded,
                    color: const Color(0xFF15803D),
                  ),
                  _PulseMetric(
                    title: 'Recorded expenses',
                    value: _pulseMoney(totalExpenses),
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Signals to review',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (entries.isEmpty && expenses.isEmpty)
                    const _PulseInsight(
                      icon: Icons.insights_outlined,
                      title: 'Your first insight starts here',
                      message:
                          'Record transactions and expenses to see trends and concentration signals.',
                    ),
                  if (change != null)
                    _PulseInsight(
                      icon: change >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      title: change >= 0
                          ? 'Collections are up'
                          : 'Collections have slowed',
                      message:
                          'Recorded collections changed by ${change.abs()}% compared with the previous 30-day period.',
                      color: change >= 0
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309),
                    )
                  else
                    _PulseInsight(
                      icon: Icons.calendar_month_outlined,
                      title: 'Building your collection baseline',
                      message: collectionsNow == 0
                          ? 'No payments received in the last 30 days are recorded yet.'
                          : 'You have ${_pulseMoney(collectionsNow)} in recorded collections. Another 30-day period enables a comparison.',
                    ),
                  if (topDebtors.isNotEmpty)
                    _PulseInsight(
                      icon: Icons.person_search_rounded,
                      title: 'Largest customer balance',
                      message:
                          '${topDebtors.first.key} has the largest positive net receivable: ${_pulseMoney(topDebtors.first.value)}. This is not an overdue judgment.',
                    ),
                  if (topCreditors.isNotEmpty)
                    _PulseInsight(
                      icon: Icons.storefront_outlined,
                      title: 'Largest supplier balance',
                      message:
                          'Your largest positive net payable is with ${topCreditors.first.key}: ${_pulseMoney(topCreditors.first.value)}.',
                    ),
                  if (topCategories.isNotEmpty)
                    _PulseInsight(
                      icon: Icons.pie_chart_outline_rounded,
                      title: 'Top expense category',
                      message:
                          '${topCategories.first.key} is your largest recorded expense category at ${_pulseMoney(topCategories.first.value)}.',
                    ),
                  const SizedBox(height: 10),
                  const Text(
                    'Pulse uses saved entries only. It cannot determine overdue balances because due dates are not recorded in this version.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PulseMetric extends StatelessWidget {
  const _PulseMetric({
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE5EAF0)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ],
    ),
  );
}

class _PulseInsight extends StatelessWidget {
  const _PulseInsight({
    required this.icon,
    required this.title,
    required this.message,
    this.color = const Color(0xFF176B5B),
  });
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE5EAF0)),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(
                message,
                style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PulseState extends StatelessWidget {
  const _PulseState({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Color(0xFF64748B),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    ),
  );
}

String _pulseMoney(int minor) {
  final negative = minor < 0;
  final value = minor.abs();
  final rupees = (value ~/ 100).toString();
  final digits = StringBuffer();
  for (var i = 0; i < rupees.length; i++) {
    if (i > 0 && (rupees.length - i) % 3 == 0) digits.write(',');
    digits.write(rupees[i]);
  }
  return '${negative ? '-' : ''}Rs $digits.${(value % 100).toString().padLeft(2, '0')}';
}
