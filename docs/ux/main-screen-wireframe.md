# Dashboard wireframe

One-page map of the dashboard regions touched by this change. The Material theme, greeting, period chips, net-worth pager, and speed-dial are unchanged.

```
+------------------------------------------+
| Good morning                             |
| October 26, 2026                    (o)  |
| [This Month] [Last Month] [Custom]       |
|                                          |
| +--------------------------------------+ |
| | TOTAL NET WORTH            INR  v    | |
| | ₹12,400.00                           | |
| +--------------------------------------+ |
|                                          |
|  ENTRANCE: summary panel                 |
| +------------+------------+------------+ |
| | Income     | Expense    | Net        | |
| | ₹8,000     | ₹3,200     | ₹4,800     | |
| +------------+------------+------------+ |
|                                          |
| Recent Transactions            See All   |
|                                          |
|  ENTRANCE: recent list panel             |
| +--------------------------------------+ |
| | (icon) Merchant          -₹120.00   | |
| |        SMS               Debit      | |
| +--------------------------------------+ |
| | (icon) Salary            +₹8,000.00 | |
| |        Manual            Credit     | |
| +--------------------------------------+ |
|                                          |
|                         (+) add income   |
|                         (+) add expense  |
+------------------------------------------+
```

Empty wallet (no transactions in the active currency) uses the same entrance on the "No data in {currency} yet" card instead of the summary and recent list.

## Regions changed

- Summary panel: the existing Income, Expense, and Net cards. Titles stay visible. Amount color is unchanged and is not the only cue; each card still has its text title.
- Recent transactions panel: the last few rows under "Recent Transactions". Each row keeps its signed amount (`-` or `+`) and adds a visible **Debit** or **Credit** word in the theme's on-surface color. Red and green remain secondary cues only.
- Empty-state card: the existing wallet-empty card, so the main content does not pop in when there is nothing to list.

## Motion

The summary panel, the recent-transactions panel, and the empty-state card each play one entrance: opacity from 0 to 1 and a downward slide of 8 logical pixels, 240ms, `Curves.easeOut`. No new animation package. The greeting, period chips, net-worth card, section header, and floating action button do not move.

## Reduced motion

`shouldPlayPanelEntrance` is a pure function. It returns false when `MediaQuery.disableAnimationsOf(context)` is true. In that case `PanelEntrance` returns the child directly: full opacity, no slide, no animation controller. When the flag is false, the entrance plays.
