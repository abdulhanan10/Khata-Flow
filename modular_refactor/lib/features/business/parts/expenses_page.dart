part of '../business_home_screen.dart';

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
        final total = expenses.fold<int>(0, (sum, item) => sum + item.amountMinor);

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
              const Text('Business expenses',
                  style: TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 6),
              const Text('Keep operational spending visible and organized.',
                  style: TextStyle(color: _muted, fontSize: 13)),
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
                    const Icon(Icons.payments_outlined,
                        color: Colors.white, size: 28),
                    const SizedBox(height: 14),
                    const Text('Total recorded expenses',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 5),
                    Text(formatMoney(total),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text('${expenses.length} expense record(s)',
                        style: const TextStyle(color: Colors.white70)),
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
                  message: 'Add rent, purchases, utilities, and other business costs here.',
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    prefixIcon: Icon(Icons.category_outlined)),
                items: _expenseCategories
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _category = value ?? _expenseCategories.first),
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
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
            child: const Icon(Icons.payments_outlined, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.category,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: _ink)),
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
          Text(formatMoney(expense.amountMinor),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: _ink, fontSize: 12)),
        ],
      ),
    );
  }
}
