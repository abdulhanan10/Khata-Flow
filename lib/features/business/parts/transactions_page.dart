part of '../business_home_screen.dart';

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
