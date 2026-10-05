// Kept independent of Qt so feed validation and unit conversion can be tested.
var gramsPerTroyOunce = 31.1034768;

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
