part of '../business_home_screen.dart';

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
