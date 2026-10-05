// Kept independent of Qt so feed validation and unit conversion can be tested.
var gramsPerTroyOunce = 31.1034768;
var currencies = ["AED", "USD", "EUR", "GBP", "INR", "JPY", "CAD", "AUD", "CHF", "CNY"];
var metalNames = ["Gold", "Silver", "Platinum", "Palladium"];

function preferences(settings) {
  var s = settings || {};
  var legacyUsd = s.displayMode === "USD/oz";
  return {
    currency: currencies.indexOf(s.currency) >= 0 ? s.currency : legacyUsd ? "USD" : "AED",
    unit: ["g", "oz", "kg"].indexOf(s.unit) >= 0 ? s.unit : legacyUsd ? "oz" : "g",
    primaryMetal: metalNames.indexOf(s.primaryMetal) >= 0 ? s.primaryMetal : "Gold",
    secondaryMetal: ["None"].concat(metalNames).indexOf(s.secondaryMetal) >= 0 ? s.secondaryMetal : "Silver",
    barDisplay: ["Selected", "Both"].indexOf(s.barDisplay) >= 0 ? s.barDisplay : s.displayMode === "Both" ? "Both" : "Selected",
    showReference: s.showReference !== false,
    refreshSeconds: Math.min(3600, refreshSeconds(s.refreshSeconds)),
    usdToAed: positiveNumber(s.usdToAed, 3.6725),
    chartMetal: metalNames.indexOf(s.chartMetal) >= 0 ? s.chartMetal : "Gold",
    chartHours: [1, 6, 24].indexOf(Number(s.chartHours)) >= 0 ? Number(s.chartHours) : 1
  };
}

function validatePatch(patch) {
  if (!patch || typeof patch !== "object" || Array.isArray(patch)) throw new Error("Settings must be an object");
  var enums = { currency: currencies, unit: ["g", "oz", "kg"], primaryMetal: metalNames,
    secondaryMetal: ["None"].concat(metalNames), barDisplay: ["Selected", "Both"], chartMetal: metalNames };
  Object.keys(patch).forEach(function(key) {
    var value = patch[key];
    if (enums[key]) { if (enums[key].indexOf(value) < 0) throw new Error("Invalid " + key); }
    else if (key === "showReference") { if (typeof value !== "boolean") throw new Error("Invalid " + key); }
    else if (key === "chartHours") { if ([1, 6, 24].indexOf(value) < 0) throw new Error("Invalid chart range"); }
    else if (key === "refreshSeconds") {
      if (typeof value !== "number" || !isFinite(value) || value < 30 || value > 3600) throw new Error("Refresh must be 30–3600 seconds");
    } else if (key === "usdToAed") {
      if (typeof value !== "number" || !isFinite(value) || value <= 0 || value > 1000) throw new Error("Enter a positive AED rate up to 1000");
    } else throw new Error("Unknown setting: " + key);
  });
  return patch;
}

function unitName(unit) { return unit === "oz" ? "troy oz" : unit === "kg" ? "kilogram" : "gram"; }
function convertedPrice(usdPerOunce, rate, unit) {
  if (typeof rate !== "number" || !isFinite(rate) || rate <= 0) return null;
  return usdPerOunce * rate * (unit === "oz" ? 1 : unit === "kg" ? 1000 / gramsPerTroyOunce : 1 / gramsPerTroyOunce);
}

function normalizeRate(raw, currency, now) {
  if (!raw || raw.symbol !== "XAU" || raw.currency !== currency || currencies.indexOf(currency) < 0
    || typeof raw.exchangeRate !== "number" || !isFinite(raw.exchangeRate) || raw.exchangeRate <= 0)
    throw new Error("Invalid currency response");
  var timestamp = Date.parse(raw.updatedAt);
  if (!isFinite(timestamp) || timestamp > now + 300000) throw new Error("Invalid currency timestamp");
  return { rate: raw.exchangeRate, fetchedAt: now };
}

function selectedBarLabel(rows, prefs, rate, fxOffline, now, vertical) {
  var selected = rows.filter(function(row) { return row.name === prefs.primaryMetal || row.name === prefs.secondaryMetal; });
  selected.sort(function(a) { return a.name === prefs.primaryMetal ? -1 : 1; });
  return selected.map(function(row) {
    var marker = row.error || fxOffline || !rate || (row.quote.price && isStale(row.quote, now, prefs.refreshSeconds)) ? " !" : "";
    if (vertical) return row.shortName + marker;
    var value = row.quote.price ? numberText(convertedPrice(row.quote.price, rate, prefs.unit)) : "—";
    if (prefs.barDisplay === "Both") value += " / " + (row.quote.price ? "$" + numberText(row.quote.price) : "—");
    return row.shortName + " " + value + marker;
  }).join(vertical ? "\n" : "  ·  ") + (vertical ? "" : " " + prefs.currency + "/" + prefs.unit + (prefs.barDisplay === "Both" ? " · USD/oz" : ""));
}

function positiveNumber(value, fallback) {
  var number = Number(value);
  return isFinite(number) && number > 0 ? number : fallback;
}

function refreshSeconds(value) {
  return Math.max(30, positiveNumber(value, 60));
}

function displayMode(value) {
  return ["AED/g", "USD/oz", "Both"].indexOf(value) >= 0 ? value : "AED/g";
}

function normalizeQuote(raw, symbol, now) {
  if (!raw || raw.symbol !== symbol || (raw.currency && raw.currency !== "USD"))
    throw new Error("Unexpected symbol or currency");
  if (typeof raw.price !== "number" || !isFinite(raw.price) || raw.price <= 0)
    throw new Error("Invalid price");
  var timestamp = typeof raw.updatedAt === "string" ? Date.parse(raw.updatedAt) : NaN;
  if (!isFinite(timestamp) || timestamp > now + 300000)
    throw new Error("Invalid quote timestamp");
  return { price: raw.price, updatedAt: timestamp };
}

function aedPerGram(usdPerOunce, rate) {
  return usdPerOunce * positiveNumber(rate, 3.6725) / gramsPerTroyOunce;
}

function numberText(value) {
  if (typeof value !== "number" || !isFinite(value)) return "—";
  var parts = value.toFixed(2).split(".");
  parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return parts.join(".");
}

function isStale(quote, now, interval) {
  return !quote || !quote.updatedAt || now - quote.updatedAt > Math.max(180, interval * 3) * 1000;
}

function ageText(quote, now) {
  if (!quote || !quote.updatedAt) return "No quote yet";
  var seconds = Math.max(0, Math.floor((now - quote.updatedAt) / 1000));
  if (seconds < 60) return seconds + "s ago";
  if (seconds < 3600) return Math.floor(seconds / 60) + "m ago";
  if (seconds < 86400) return Math.floor(seconds / 3600) + "h ago";
  return Math.floor(seconds / 86400) + "d ago";
}

function quoteStatus(quote, error, now, interval) {
  if (error) return quote && quote.price ? "Offline · last quote " + ageText(quote, now) : error;
  if (!quote || !quote.price) return "Loading…";
  return (isStale(quote, now, interval) ? "Stale · " : "Updated ") + ageText(quote, now);
}

function barLabel(rows, mode, rate, now, interval, vertical) {
  var labels = rows.slice(0, 2).map(function(row) {
    var quote = row.quote;
    var marker = row.error || (quote.price && isStale(quote, now, interval)) ? " !" : "";
    if (vertical) return row.shortName + marker;
    var usd = quote.price ? "$" + numberText(quote.price) : "—";
    var aed = quote.price ? numberText(aedPerGram(quote.price, rate)) : "—";
    var price = mode === "USD/oz" ? usd : mode === "Both" ? usd + " / " + aed : aed;
    return row.shortName + " " + price + marker;
  });
  return labels.join(vertical ? "\n" : "  ·  ") + (vertical ? "" : mode === "Both" ? " USD/oz · AED/g" : " " + mode);
}

// Keep genuine provider timestamps; an unchanged or stale response is not a new tick.
function cleanHistory(points, now) {
  if (!Array.isArray(points)) return [];
  var sorted = points.filter(function(p) {
    return p && typeof p.price === "number" && isFinite(p.price) && p.price > 0
      && typeof p.updatedAt === "number" && isFinite(p.updatedAt)
      && p.updatedAt >= now - 86400000 && p.updatedAt <= now;
  }).sort(function(a, b) { return a.updatedAt - b.updatedAt; });
  return sorted.filter(function(p, i) {
    return i === sorted.length - 1 || p.updatedAt !== sorted[i + 1].updatedAt;
  }).slice(-2880);
}

function appendSample(points, quote, now) {
  return cleanHistory((points || []).concat([quote]), now);
}

function windowSamples(points, now, hours) {
  return cleanHistory(points, now).filter(function(p) {
    return p.updatedAt >= now - hours * 3600000;
  });
}

function trendStats(points) {
  if (!points.length) return null;
  var prices = points.map(function(p) { return p.price; });
  var first = prices[0], last = prices[prices.length - 1];
  return { first: first, last: last, low: Math.min.apply(null, prices),
    high: Math.max.apply(null, prices), change: last - first, percent: (last / first - 1) * 100 };
}
