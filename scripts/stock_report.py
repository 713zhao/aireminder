#!/usr/bin/env python3
import os, sys, yfinance as yf
from datetime import datetime

OUTPUT_DIR = os.path.expanduser("/home/eric/projects/VideoAgent/output/latest")
os.makedirs(OUTPUT_DIR, exist_ok=True)

US_TICKERS = ["AAPL", "MSFT", "GOOGL", "AMZN", "META", "NVDA", "TSLA", "AMD", "INTC", "CSCO"]
HK_TICKERS = ["0700.HK", "9988.HK", "0939.HK", "1398.HK", "0881.HK", "0016.HK", "1024.HK", "2020.HK", "9969.HK", "0700.HK"]
CN_TICKERS = ["000001.SZ", "000002.SZ", "000651.SZ", "002415.SZ", "300750.SZ", "600519.SS", "600036.SS", "601318.SS", "601012.SS", "603259.SS"]
INDICES = {"US": "^GSPC", "HK": "^HSI", "CN": "000300.SS"}

def get_metrics(ticker):
    try:
        df = yf.download(ticker, period="1mo", interval="1d", progress=False, auto_adjust=True)
        if df.empty or len(df) < 2:
            return None
        df = df[['Close', 'Volume']].dropna()
        if len(df) < 2:
            return None
        prev_close = df['Close'].iloc[-2]
        cur_close = df['Close'].iloc[-1]
        change_pct = ((cur_close - prev_close) / prev_close) * 100
        vol = df['Volume'].iloc[-1]
        avg_vol = df['Volume'].iloc[-20:].mean()
        rel_vol = vol / avg_vol if avg_vol > 0 else 1.0
        ma50 = df['Close'].iloc[-50:].mean() if len(df) >= 50 else cur_close
        above_ma50 = cur_close > ma50
        return {
            'ticker': ticker,
            'date': df.index[-1].strftime("%Y-%m-%d"),
            'close': float(cur_close),
            'change_pct': round(change_pct, 2),
            'volume': int(vol),
            'rel_volume': round(rel_vol, 2),
            'above_ma50': above_ma50,
            'ma50': round(ma50, 2)
        }
    except Exception as e:
        print(f"Error {ticker}: {e}", file=sys.stderr)
        return None

def generate_report():
    today_str = datetime.now().strftime("%Y-%m-%d")
    lines = [f"# Daily Stock Report — {today_str}\n", "Markets: US (S&P 500), Hong Kong (Hang Seng), China (CSI300)\n", "---\n"]

    lines.append("## Index Performance (Latest Trading Day)\n")
    for name, ticker in INDICES.items():
        m = get_metrics(ticker)
        if m:
            lines.append(f"- {name} ({ticker}): {m['close']:,.2f} ({m['change_pct']:+.2f}%) on {m['date']}")
        else:
            lines.append(f"- {name}: No data")
    lines.append("\n")

    regions = {"US": US_TICKERS, "Hong Kong": HK_TICKERS, "China": CN_TICKERS}
    all_stats = []

    for region_name, tickers in regions.items():
        lines.append(f"## {region_name} — Top Movers (Latest)\n")
        stats = []
        for t in tickers:
            m = get_metrics(t)
            if m:
                m['region'] = region_name
                stats.append(m)
        stats.sort(key=lambda x: (x['change_pct'], x['rel_volume']), reverse=True)
        for s in stats[:3]:
            lines.append(f"- **{s['ticker']}**: {s['change_pct']:+.2f}% (Vol {s['rel_volume']}x avg), above 50‑day MA: {s['above_ma50']}")
        lines.append("\n")
        all_stats.extend(stats[:5])

    lines.append("## Top 5 Suggestions (Educational Only)\n")
    all_stats.sort(key=lambda x: (x['change_pct'], x['rel_volume']), reverse=True)
    top5 = all_stats[:5]
    for i, s in enumerate(top5, 1):
        reasons = []
        if s['change_pct'] > 0:
            reasons.append(f"up {s['change_pct']}%")
        else:
            reasons.append(f"down {abs(s['change_pct'])}%")
        reasons.append(f"volume {s['rel_volume']}x avg")
        reasons.append("above 50‑day MA" if s['above_ma50'] else "below 50‑day MA")
        lines.append(f"{i}. **{s['ticker']}** ({s['region']}) — {'; '.join(reasons)}")

    lines.append("\n---\n*Disclaimer: This is not financial advice.*")

    content = "\n".join(lines)
    fname = f"stock_report_{today_str}.md"
    fpath = os.path.join(OUTPUT_DIR, fname)
    with open(fpath, "w", encoding="utf-8") as f:
        f.write(content)
    with open(os.path.join(OUTPUT_DIR, "stock_report_latest.md"), "w", encoding="utf-8") as f:
        f.write(content)
    return fpath, content

if __name__ == "__main__":
    try:
        path, content = generate_report()
        print(f"Report generated: {path}")
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback; traceback.print_exc()
        sys.exit(1)
