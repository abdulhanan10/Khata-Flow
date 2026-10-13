import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

DateTime _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}

int _readInt(Object? value) => value is num ? value.toInt() : 0;

class BusinessRecord {
  const BusinessRecord({
    required this.id,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.ownerId,
  });

  final String id;
  final String name;
  final String type;
  final String currencyCode;
  final String ownerId;

  factory BusinessRecord.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return BusinessRecord(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Untitled business',
      type: (data['type'] as String?) ?? 'General',
      currencyCode: (data['currencyCode'] as String?) ?? 'PKR',
      ownerId: (data['ownerId'] as String?) ?? '',
    );
  }
}

class PartyRecord {
  const PartyRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.type,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String type;
  final String notes;
  final DateTime createdAt;

  factory PartyRecord.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return PartyRecord(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Unnamed party',
      phone: (data['phone'] as String?) ?? '',
      type: (data['partyType'] as String?) ?? 'customer',
      notes: (data['notes'] as String?) ?? '',
      createdAt: _readDate(data['createdAt']),
    );
  }
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.partyId,
    required this.partyName,
    required this.kind,
    required this.amountMinor,
    required this.description,
    required this.occurredAt,
  });

  final String id;
  final String partyId;
  final String partyName;
  final String kind;
  final int amountMinor;
  final String description;
  final DateTime occurredAt;

  factory LedgerEntry.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return LedgerEntry(
      id: doc.id,
      partyId: (data['partyId'] as String?) ?? '',
      partyName: (data['partyName'] as String?) ?? 'Unknown party',
      kind: (data['transactionType'] as String?) ?? 'credit_given',
      amountMinor: _readInt(data['amountMinor']),
      description: (data['description'] as String?) ?? '',
      occurredAt: _readDate(data['occurredAt']),
    );
  }
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.amountMinor,
    required this.category,
    required this.description,
    required this.occurredAt,
  });

  final String id;
  final int amountMinor;
  final String category;
  final String description;
  final DateTime occurredAt;

  factory ExpenseRecord.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return ExpenseRecord(
      id: doc.id,
      amountMinor: _readInt(data['amountMinor']),
      category: (data['category'] as String?) ?? 'Other',
      description: (data['description'] as String?) ?? '',
      occurredAt: _readDate(data['occurredAt']),
    );
  }
}

/// Firestore access for KhataFlow. All ledger data is nested under a business.
class KhataFlowRepository {
  KhataFlowRepository({FirebaseFirestore? firestore, String? userId})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _userIdOverride = userId;

  final FirebaseFirestore _firestore;
  final String? _userIdOverride;

  String get userId {
    final id = _userIdOverride ?? FirebaseAuth.instance.currentUser?.uid;
    if (id == null || id.isEmpty) {
      throw StateError(
        'A signed-in user is required to access KhataFlow data.',
      );
    }
    return id;
  }

  CollectionReference<Map<String, dynamic>> get _businesses =>
      _firestore.collection('businesses');

  DocumentReference<Map<String, dynamic>> _business(String businessId) =>
      _businesses.doc(businessId);

  CollectionReference<Map<String, dynamic>> _parties(String businessId) =>
      _business(businessId).collection('parties');

  CollectionReference<Map<String, dynamic>> _transactions(String businessId) =>
      _business(businessId).collection('transactions');

  CollectionReference<Map<String, dynamic>> _expenses(String businessId) =>
      _business(businessId).collection('expenses');

  Stream<List<BusinessRecord>> watchBusinesses() {
    return _businesses.where('ownerId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      final items = snapshot.docs.map(BusinessRecord.fromDocument).toList();
      items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return items;
    });
  }

  Future<String> createBusiness({
    required String name,
    required String type,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Business name is required.');

    final id = userId;
    final doc = _businesses.doc();
    final batch = _firestore.batch();
    batch.set(doc, {
      'name': cleanName,
      'type': type,
      'ownerId': id,
      'currencyCode': 'PKR',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(doc.collection('members').doc(id), {
      'userId': id,
      'role': 'owner',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return doc.id;
  }

  Stream<List<PartyRecord>> watchParties(String businessId) {
    return _parties(businessId).snapshots().map((snapshot) {
      final items = snapshot.docs.map(PartyRecord.fromDocument).toList();
      items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return items;
    });
  }

  Future<void> saveParty({
    required String businessId,
    String? partyId,
    required String name,
    required String phone,
    required String type,
    required String notes,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError('Party name is required.');

    final collection = _parties(businessId);
    final doc = partyId == null ? collection.doc() : collection.doc(partyId);
    final data = <String, dynamic>{
      'name': cleanName,
      'phone': phone.trim(),
      'partyType': type,
      'notes': notes.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (partyId == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['createdBy'] = userId;
      await doc.set(data);
    } else {
      await doc.update(data);
    }
  }

  Stream<List<LedgerEntry>> watchTransactions(String businessId) {
    return _transactions(businessId)
        .orderBy('occurredAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(LedgerEntry.fromDocument).toList(),
        );
  }

  Future<void> addTransaction({
    required String businessId,
    required PartyRecord party,
    required String kind,
    required int amountMinor,
    required String description,
    DateTime? occurredAt,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    const allowed = {
      'credit_given',
      'payment_received',
      'credit_taken',
      'payment_made',
    };
    if (!allowed.contains(kind)) {
      throw ArgumentError('Invalid transaction type.');
    }

    await _transactions(businessId).add({
      'partyId': party.id,
      'partyName': party.name,
      'partyType': party.type,
      'transactionType': kind,
      'amountMinor': amountMinor,
      'description': description.trim(),
      'occurredAt': Timestamp.fromDate(occurredAt ?? DateTime.now()),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': userId,
    });
  }

  Stream<List<ExpenseRecord>> watchExpenses(String businessId) {
    return _expenses(businessId)
        .orderBy('occurredAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(ExpenseRecord.fromDocument).toList(),
        );
  }

  Future<void> addExpense({
    required String businessId,
    required int amountMinor,
    required String category,
    required String description,
    DateTime? occurredAt,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    await _expenses(businessId).add({
      'amountMinor': amountMinor,
      'category': category,
      'description': description.trim(),
      'occurredAt': Timestamp.fromDate(occurredAt ?? DateTime.now()),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': userId,
    });
  }
}
