const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../Model.js`, 'utf8'), model);
const now = Date.parse('2026-10-05T04:30:00Z');
const raw = { symbol: 'XAU', currency: 'USD', price: 4133.2, updatedAt: '2026-10-05T04:29:30Z' };

test('converts a troy ounce to grams before converting currency', () => {
  assert.ok(Math.abs(model.aedPerGram(31.1034768, 3.6725) - 3.6725) < 1e-12);
  assert.equal(model.numberText(model.aedPerGram(raw.price, 3.6725)), '488.02');
  assert.equal(model.numberText(raw.price), '4,133.20');
});

test('rejects prices, currencies, symbols and timestamps that would mislead the display', () => {
  assert.equal(model.normalizeQuote(raw, 'XAU', now).price, 4133.2);
  for (const change of [
    { price: 0 }, { price: -1 }, { price: '4133' }, { price: null }, { price: Infinity },
    { symbol: 'XAG' }, { currency: 'EUR' }, { updatedAt: null },
    { updatedAt: 'bad-date' }, { updatedAt: '2026-10-06T00:00:00Z' }
  ]) assert.throws(() => model.normalizeQuote({ ...raw, ...change }, 'XAU', now));
});

test('uses provider quote age and exposes stale and offline values', () => {
  const quote = model.normalizeQuote(raw, 'XAU', now);
  assert.equal(model.isStale(quote, now, 60), false);
  assert.equal(model.isStale(quote, now + 181000, 60), true);
  assert.equal(model.quoteStatus(quote, 'Feed unreachable', now, 60), 'Offline · last quote 30s ago');
  assert.equal(model.quoteStatus({}, 'Feed timed out', now, 60), 'Feed timed out');
  const rows = [{ shortName: 'Au', quote, error: '' }, { shortName: 'Ag', quote: {}, error: 'Feed unreachable' }];
  assert.match(model.barLabel(rows, 'AED/g', 3.6725, now, 60, false), /Au 488\.02.*Ag — !.*AED\/g/);
  assert.match(model.barLabel(rows, 'Both', 3.6725, now + 181000, 60, false), /Au \$4,133\.20 \/ 488\.02 !/);
});

test('bounds refresh frequency and falls back for invalid settings', () => {
  assert.equal(model.refreshSeconds(1), 30);
  assert.equal(model.refreshSeconds('bad'), 60);
  assert.equal(model.refreshSeconds(120), 120);
  assert.equal(model.displayMode('invalid'), 'AED/g');
  assert.equal(model.positiveNumber(-1, 3.6725), 3.6725);
});

test('history ignores invalid and expired quotes, deduplicates timestamps and sorts observations', () => {
  const points = [
    { price: 100, updatedAt: now - 60000 },
    { price: 103, updatedAt: now - 30000 },
    { price: 102, updatedAt: now - 60000 },
    { price: 0, updatedAt: now },
    { price: 99, updatedAt: now - 86400001 },
    { price: 105, updatedAt: now + 1 }
  ];
  const clean = model.cleanHistory(points, now);
  assert.equal(clean.length, 2);
  assert.equal(clean[0].price, 102);
  assert.equal(model.appendSample(clean, clean[1], now).length, 2);
  assert.equal(model.cleanHistory({ broken: true }, now).length, 0);
});

test('trend windows and changes use only actual collected observations', () => {
  const points = [
    { price: 90, updatedAt: now - 7200000 },
    { price: 100, updatedAt: now - 120000 },
    { price: 110, updatedAt: now - 60000 }
  ];
  const window = model.windowSamples(points, now, 1);
  assert.equal(window.length, 2);
  const stats = model.trendStats(window);
  assert.equal(stats.low, 100);
  assert.equal(stats.high, 110);
  assert.equal(stats.change, 10);
  assert.ok(Math.abs(stats.percent - 10) < 1e-9);
  assert.equal(model.trendStats([]), null);
  assert.equal(model.trendStats([{ price: 100 }]).percent, 0);
});

test('preferences migrate legacy display modes and preserve explicit choices', () => {
  assert.equal(model.preferences({ displayMode: 'USD/oz' }).currency, 'USD');
  assert.equal(model.preferences({ displayMode: 'USD/oz' }).unit, 'oz');
  assert.equal(model.preferences({ displayMode: 'Both' }).barDisplay, 'Both');
  const prefs = model.preferences({ displayMode: 'USD/oz', currency: 'INR', unit: 'kg', refreshSeconds: 99999 });
  assert.equal(prefs.currency, 'INR');
  assert.equal(prefs.unit, 'kg');
  assert.equal(prefs.refreshSeconds, 3600);
  assert.equal(model.preferences({ currency: 'invalid', unit: 'lb', chartHours: 12 }).chartHours, 1);
});

test('converts all three weight units without inventing a missing FX rate', () => {
  const ounce = model.gramsPerTroyOunce;
  assert.ok(Math.abs(model.convertedPrice(ounce, 96.4, 'g') - 96.4) < 1e-9);
  assert.equal(model.convertedPrice(100, 0.88, 'oz'), 88);
  assert.ok(Math.abs(model.convertedPrice(ounce, 96.4, 'kg') - 96400) < 1e-9);
  assert.equal(model.convertedPrice(100, 0, 'g'), null);
  assert.equal(model.numberText(model.convertedPrice(100, undefined, 'oz')), '—');
  assert.equal(model.convertedPrice(-100, 0.88, 'oz'), -88);
});

test('currency responses must match the requested currency and contain a valid rate', () => {
  const response = { ...raw, currency: 'EUR', exchangeRate: 0.88 };
  assert.equal(model.normalizeRate(response, 'EUR', now).rate, 0.88);
  for (const change of [{ currency: 'INR' }, { symbol: 'XAG' }, { exchangeRate: 0 },
    { exchangeRate: '0.88' }, { exchangeRate: Infinity }, { updatedAt: null },
    { updatedAt: '2026-10-06T00:00:00Z' }]) {
    assert.throws(() => model.normalizeRate({ ...response, ...change }, 'EUR', now));
  }
});

test('invalid settings patches are rejected before any preferences are saved', () => {
  model.validatePatch({ currency: 'INR', unit: 'kg', chartHours: 24, secondaryMetal: 'None', showReference: false });
  for (const patch of [null, [], { currency: 'XYZ' }, { unit: 'lb' }, { refreshSeconds: 29 },
    { refreshSeconds: 3601 }, { usdToAed: -1 }, { usdToAed: Infinity },
    { showReference: 'false' }, { chartHours: 12 }, { unknown: true }]) {
    assert.throws(() => model.validatePatch(patch));
  }
});

test('bar metal selection orders, deduplicates and marks missing conversions', () => {
  const quote = model.normalizeQuote(raw, 'XAU', now);
  const rows = [{ name: 'Gold', shortName: 'Au', quote, error: '' },
    { name: 'Silver', shortName: 'Ag', quote, error: '' }];
  let prefs = model.preferences({ primaryMetal: 'Silver', secondaryMetal: 'Gold', currency: 'EUR', unit: 'oz' });
  assert.match(model.selectedBarLabel(rows, prefs, 0.88, false, now, false), /^Ag 3,637\.22.*Au 3,637\.22.*EUR\/oz$/);
  prefs = model.preferences({ primaryMetal: 'Silver', secondaryMetal: 'Silver', currency: 'INR' });
  const label = model.selectedBarLabel(rows, prefs, 0, true, now, false);
  assert.equal((label.match(/Ag/g) || []).length, 1);
  assert.match(label, /^Ag — ! INR\/g$/);
  assert.doesNotMatch(label, /Au/);
});
