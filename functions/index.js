const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { GoogleGenerativeAI } = require('@google/generative-ai');

initializeApp();
const db = getFirestore();
const geminiApiKey = defineSecret('GEMINI_API_KEY');

exports.askKhataFlow = onCall({ region: 'us-central1', secrets: [geminiApiKey], timeoutSeconds: 60, memory: '256MiB' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in before asking about your business.');
  const businessId = typeof request.data?.businessId === 'string' ? request.data.businessId.trim() : '';
  const question = typeof request.data?.question === 'string' ? request.data.question.trim() : '';
  if (!businessId || businessId.length > 180) throw new HttpsError('invalid-argument', 'A valid business is required.');
  if (!question || question.length > 1200) throw new HttpsError('invalid-argument', 'Enter a question between 1 and 1200 characters.');

  const businessRef = db.collection('businesses').doc(businessId);
  const businessSnap = await businessRef.get();
  if (!businessSnap.exists) throw new HttpsError('not-found', 'Business not found.');
  const business = businessSnap.data();
  const uid = request.auth.uid;
  const isOwner = business.ownerId === uid;
  const membership = isOwner ? null : await businessRef.collection('members').doc(uid).get();
  if (!isOwner && !membership?.exists) throw new HttpsError('permission-denied', 'You do not have access to this business.');
  if (!geminiApiKey.value()) throw new HttpsError('failed-precondition', 'The Gemini API key has not been configured.');

  const [partySnap, txSnap, expenseSnap] = await Promise.all([
    businessRef.collection('parties').limit(500).get(),
    businessRef.collection('transactions').orderBy('occurredAt', 'desc').limit(500).get(),
    businessRef.collection('expenses').orderBy('occurredAt', 'desc').limit(300).get(),
  ]);
  const parties = new Map(partySnap.docs.map((doc) => [doc.id, doc.data()]));
  const balances = new Map();
  let receivable = 0;
  let payable = 0;
  let collected30Days = 0;
  let expenseTotal = 0;
  const categoryTotals = {};
  const now = Date.now();
  const thirtyDays = now - 30 * 24 * 60 * 60 * 1000;
  const transactions = txSnap.docs.map((doc) => {
    const item = doc.data();
    const amount = Number.isSafeInteger(item.amountMinor) ? item.amountMinor : 0;
    const partyId = String(item.partyId || '');
    const partyName = String(item.partyName || parties.get(partyId)?.name || 'Unknown party');
    const balance = balances.get(partyId) || { name: partyName, receivable: 0, payable: 0 };
    if (item.transactionType === 'credit_given') { receivable += amount; balance.receivable += amount; }
    if (item.transactionType === 'payment_received') {
      receivable -= amount; balance.receivable -= amount;
      if (item.occurredAt?.toMillis && item.occurredAt.toMillis() >= thirtyDays) collected30Days += amount;
    }
    if (item.transactionType === 'credit_taken') { payable += amount; balance.payable += amount; }
    if (item.transactionType === 'payment_made') { payable -= amount; balance.payable -= amount; }
    balances.set(partyId, balance);
    return { date: item.occurredAt?.toDate ? item.occurredAt.toDate().toISOString().slice(0, 10) : null, party: partyName, type: item.transactionType, amountMinor: amount, note: String(item.description || '').slice(0, 160) };
  });
  const expenses = expenseSnap.docs.map((doc) => {
    const item = doc.data();
    const amount = Number.isSafeInteger(item.amountMinor) ? item.amountMinor : 0;
    const category = String(item.category || 'Other');
    expenseTotal += amount;
    categoryTotals[category] = (categoryTotals[category] || 0) + amount;
    return { category, amountMinor: amount, date: item.occurredAt?.toDate ? item.occurredAt.toDate().toISOString().slice(0, 10) : null, note: String(item.description || '').slice(0, 120) };
  });
  const topDebtors = [...balances.values()].filter((item) => item.receivable > 0).sort((a, b) => b.receivable - a.receivable).slice(0, 12);
  const topCreditors = [...balances.values()].filter((item) => item.payable > 0).sort((a, b) => b.payable - a.payable).slice(0, 12);
  const topExpenseCategories = Object.entries(categoryTotals).sort((a, b) => b[1] - a[1]).slice(0, 8).map(([category, amountMinor]) => ({ category, amountMinor }));
  const context = {
    businessName: String(business.name || 'Business'),
    currency: String(business.currencyCode || 'PKR'),
    recordLimits: { transactionsIncluded: transactions.length, partiesIncluded: partySnap.size, expensesIncluded: expenses.length, transactionsMayBeTruncated: txSnap.size >= 500, expensesMayBeTruncated: expenseSnap.size >= 300 },
    totalsMinorUnits: { netReceivable: receivable, netPayable: payable, collectionsLast30Days: collected30Days, totalRecordedExpenses: expenseTotal },
    topCustomerBalances: topDebtors,
    topSupplierBalances: topCreditors,
    topExpenseCategories,
    recentTransactions: transactions.slice(0, 25),
    recentExpenses: expenses.slice(0, 20),
  };
  try {
    const genAI = new GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash', generationConfig: { temperature: 0.2, maxOutputTokens: 700 } });
    const result = await model.generateContent([
      'You are KhataFlow, a careful assistant for small-business bookkeeping. Answer the user using only the JSON business data supplied below. Amounts are in minor currency units (100 = 1 major unit), and currency code is included. Never invent transactions, dates, due dates, or figures. If data is incomplete or limited, say so. Clearly distinguish gross ledger totals from net balances. A positive receivable means a customer owes the business; a positive payable means the business owes a supplier. If a question cannot be answered from the available data, explain the limitation and suggest which record to add. Keep the answer concise, practical, and readable aloud. Do not give tax, legal, or investment advice.',
      `BUSINESS DATA JSON:\n${JSON.stringify(context)}`,
      `USER QUESTION:\n${question}`,
    ].join('\n\n'));
    return { answer: result.response.text(), model: 'gemini-2.5-flash' };
  } catch (error) {
    console.error('Gemini request failed', error?.message || error);
    throw new HttpsError('unavailable', 'The AI service could not respond right now. Check API limits and try again.');
  }
});
