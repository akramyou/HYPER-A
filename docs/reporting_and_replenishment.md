# Reporting and replenishment design

## Implemented locally

- Date-range report filters for expiry and historical sales/snapshot analysis.
- Inventory status filters: expired, near expiry, negative, zero/out-of-stock, critical, low, available, and promotional flyer.
- Sales-performance views: top sellers, slow movers, positive turnover, low days-cover, and no sales in the selected period.
- Local historical snapshots are retained by report date. A later import updates current stock counters but does not overwrite item batch production/expiry dates.
- Per-item reorder threshold is optional. Empty or negative sentinel means use the branch default; explicit non-negative values override it.

## External reference patterns (English product documentation)

Zoho Inventory's quantity turnover report uses a date range, opening/closing stock, quantity sold, average stock, turnover ratio and average turnover days:
https://www.zoho.com/us/inventory/help/reports/inventory-reports.html

Lightspeed Retail's sell-through report uses a selected period, items sold per day, sell-through rate, and days cover to support replenishment decisions:
https://x-series-support.lightspeedhq.com/hc/en-us/articles/25534083755675-Using-the-sell-through-inventory-report

These sources informed report layout and metrics, not copied implementation.

## Data limitations

- `SOLD_STK` may mean period sales or a cumulative counter. The import screen asks the user to choose; if this is not documented by the source system, the sales outputs remain estimates.
- The provided stock report has no purchase cost, retail price, supplier, or product category columns. Financial valuation, gross margin, supplier ranking, and category reports cannot be calculated reliably without those fields.
- OCR in the current ML Kit configuration is Latin-script only; Arabic expiry-label OCR requires a different tested engine.
