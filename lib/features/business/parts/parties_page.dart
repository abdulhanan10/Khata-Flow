part of '../business_home_screen.dart';

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
