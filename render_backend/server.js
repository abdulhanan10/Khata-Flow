
const express = require('express');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const app = express();
const PORT = process.env.PORT || 3000;
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'khataflow-cfd44';

initializeApp({ projectId: PROJECT_ID });

app.disable('x-powered-by');
app.use(express.json({ limit: '20kb' }));

const requestCounts = new Map();

function decodeValue(value = {}) {
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('nullValue' in value) return null;
  if ('arrayValue' in value) {
    return (value.arrayValue.values || []).map(decodeValue);
  }
  if ('mapValue' in value) {
    return decodeFields(value.mapValue.fields || {});
  }
  return null;
}

function decodeFields(fields = {}) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, decodeValue(value)])
  );
}

function decodeDocument(document) {
  return {
    id: document.name.split('/').pop(),
    ...decodeFields(document.fields || {}),
  };
}

async function firestoreRequest(path, idToken, options = {}) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}` +
    `/databases/(default)/documents/${path}`;

  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${idToken}`,
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...options.headers,
    },
  });

  if (!response.ok) {
    const error = new Error(`Firestore returned ${response.status}`);
    error.status = response.status;
    throw error;
  }

  return response.json();
}

async function readCollection(businessId, collection, idToken, limit, ordered) {
  const query = {
    from: [{ collectionId: collection }],
    limit,
  };

  if (ordered) {
    query.orderBy = [{
      field: { fieldPath: 'occurredAt' },
      direction: 'DESCENDING',
    }];
  }

  const result = await firestoreRequest(
    'documents:runQuery',
    idToken,
    {
      method: 'POST',
      body: JSON.stringify({
        structuredQuery: query,
        // The query is executed beneath this business's document.
      }),
      headers: {},
    },
  ).catch(async (error) => {
    throw error;
  });

  return result
    .filter((item) => item.document)
    .map((item) => decodeDocument(item.document));
}

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'KhataFlow AI backend' });
});

app.post('/api/assistant', async (req, res) => {
  try {
    const authorization = req.headers.authorization || '';
    const match = authorization.match(/^Bearer (.+)$/);

    if (!match) {
      return res.status(401).json({ error: 'Please sign in first.' });
    }

    const decodedToken = await getAuth().verifyIdToken(match[1]);
    const uid = decodedToken.uid;

    const now = Date.now();
    const record = requestCounts.get(uid);

    if (record && now - record.start < 60 * 60 * 1000 &&
        record.count >= 20) {
      return res.status(429).json({
        error: 'AI request limit reached. Try again later.',
      });
    }

    if (!record || now - record.start >= 60 * 60 * 1000) {
      requestCounts.set(uid, { start: now, count: 1 });
    } else {
      record.count++;
    }

    const businessId =
      typeof req.body?.businessId === 'string'
        ? req.body.businessId.trim()
        : '';

    const question =
      typeof req.body?.question === 'string'
        ? req.body.question.trim()
        : '';

    if (!businessId || businessId.length > 180) {
      return res.status(400).json({ error: 'A valid business is required.' });
    }

    if (!question || question.length > 1200) {
      return res.status(400).json({
        error: 'Enter a question between 1 and 1200 characters.',
      });
    }

    if (!process.env.GEMINI_API_KEY) {
      return res.status(503).json({ error: 'AI service is not configured.' });
    }

    const idToken = match[1];
    const businessPath = `businesses/${encodeURIComponent(businessId)}`;

    let businessDocument;
    try {
      businessDocument = await firestoreRequest(businessPath, idToken);
    } catch (error) {
      if (error.status === 403 || error.status === 404) {
        return res.status(403).json({
          error: 'Business not found or you do not have access.',
        });
      }
      throw error;
    }

    const business = decodeFields(businessDocument.fields || {});

    if (business.ownerId !== uid) {
      try {
        await firestoreRequest(
          `${businessPath}/members/${encodeURIComponent(uid)}`,
          idToken,
        );
      } catch (error) {
        return res.status(403).json({
          error: 'You do not have access to this business.',
        });
      }
    }

    // Read records using the user's Firebase ID token. Firestore security
    // rules continue to apply to these requests.
    const queryCollection = async (name, limit, ordered) => {
      const query = {
        structuredQuery: {
          from: [{ collectionId: name }],
          limit,
          ...(ordered ? {
            orderBy: [{
              field: { fieldPath: 'occurredAt' },
              direction: 'DESCENDING',
            }],
          } : {}),
        },
      };

      const url =
        `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}` +
        `/databases/(default)/documents/${businessPath}:runQuery`;

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${idToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(query),
      });

      if (!response.ok) {
        const error = new Error(`Firestore query failed: ${response.status}`);
        error.status = response.status;
        throw error;
      }

      return (await response.json())
        .filter((item) => item.document)
        .map((item) => decodeDocument(item.document));
    };

    const [parties, transactions, expenses] = await Promise.all([
      queryCollection('parties', 500, false),
      queryCollection('transactions', 500, true),
      queryCollection('expenses', 300, true),
    ]);

    const partyMap = new Map(parties.map((p) => [p.id, p]));
    const balances = new Map();
    let receivable = 0;
    let payable = 0;
    let collected30Days = 0;
    let expenseTotal = 0;
    const categoryTotals = {};
    const thirtyDaysAgo = Date.now() - 30 * 86400000;

    const recentTransactions = transactions.map((item) => {
      const amount = Number.isSafeInteger(item.amountMinor)
        ? item.amountMinor : 0;
      const partyId = String(item.partyId || '');
      const partyName = String(
        item.partyName || partyMap.get(partyId)?.name || 'Unknown party',
      );

      const balance = balances.get(partyId) || {
        name: partyName, receivable: 0, payable: 0,
      };

      if (item.transactionType === 'credit_given') {
        receivable += amount;
        balance.receivable += amount;
      }
      if (item.transactionType === 'payment_received') {
        receivable -= amount;
        balance.receivable -= amount;
        if (Date.parse(item.occurredAt) >= thirtyDaysAgo) {
          collected30Days += amount;
        }
      }
      if (item.transactionType === 'credit_taken') {
        payable += amount;
        balance.payable += amount;
      }
      if (item.transactionType === 'payment_made') {
        payable -= amount;
        balance.payable -= amount;
      }

      balances.set(partyId, balance);

      return {
        date: item.occurredAt || null,
        party: partyName,
        type: item.transactionType,
        amountMinor: amount,
        note: String(item.description || '').slice(0, 160),
      };
    });

    const recentExpenses = expenses.map((item) => {
      const amount = Number.isSafeInteger(item.amountMinor)
        ? item.amountMinor : 0;
      const category = String(item.category || 'Other');
      expenseTotal += amount;
      categoryTotals[category] = (categoryTotals[category] || 0) + amount;

      return {
        category,
        amountMinor: amount,
        date: item.occurredAt || null,
        note: String(item.description || '').slice(0, 120),
      };
    });

    const context = {
      businessName: String(business.name || 'Business'),
      currency: String(business.currencyCode || 'PKR'),
      recordLimits: {
        transactionsIncluded: transactions.length,
        partiesIncluded: parties.length,
        expensesIncluded: expenses.length,
        transactionsMayBeTruncated: transactions.length >= 500,
        expensesMayBeTruncated: expenses.length >= 300,
      },
      totalsMinorUnits: {
        netReceivable: receivable,
        netPayable: payable,
        collectionsLast30Days: collected30Days,
        totalRecordedExpenses: expenseTotal,
      },
      topCustomerBalances: [...balances.values()]
        .filter((item) => item.receivable > 0)
        .sort((a, b) => b.receivable - a.receivable).slice(0, 12),
      topSupplierBalances: [...balances.values()]
        .filter((item) => item.payable > 0)
        .sort((a, b) => b.payable - a.payable).slice(0, 12),
      topExpenseCategories: Object.entries(categoryTotals)
        .sort((a, b) => b[1] - a[1]).slice(0, 8)
        .map(([category, amountMinor]) => ({ category, amountMinor })),
      recentTransactions: recentTransactions.slice(0, 25),
      recentExpenses: recentExpenses.slice(0, 20),
    };

    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({
      model: 'gemini-2.5-flash',
      generationConfig: { temperature: 0.2, maxOutputTokens: 700 },
    });

    const result = await model.generateContent([
      'You are KhataFlow, a careful small-business bookkeeping assistant. ' +
      'Use only the supplied JSON data. Amounts are in minor currency units ' +
      '(100 = 1 major unit). Never invent transactions, dates, or figures. ' +
      'Explain data limitations. Positive receivable means a customer owes ' +
      'the business; positive payable means the business owes a supplier. ' +
      'Keep answers concise and practical. Do not give tax or legal advice.',
      `BUSINESS DATA JSON:\n${JSON.stringify(context)}`,
      `USER QUESTION:\n${question}`,
    ].join('\n\n'));

    return res.json({
      answer: result.response.text(),
      model: 'gemini-2.5-flash',
    });
  } catch (error) {
    console.error('Assistant request failed:', error.message);

    if (error.code === 'auth/argument-error' ||
        error.code === 'auth/id-token-expired' ||
        error.code === 'auth/invalid-id-token') {
      return res.status(401).json({ error: 'Please sign in again.' });
    }

    return res.status(503).json({
      error: 'The assistant could not respond. Please try again.',
    });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`KhataFlow backend listening on port ${PORT}`);
});
