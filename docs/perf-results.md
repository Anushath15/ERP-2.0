# Frame-timing results (billing flow, Full animations, real Windows build)

Measured on 2026-10-13 with `tool/perf/frame_timing_main.dart` run as a **Windows profile build** (a real release-like build, not a widget test):
`flutter run -t tool/perf/frame_timing_main.dart -d windows --profile`. Machine: Intel Core i5-12500H (16 CPU threads), 16 GB RAM, Windows 11, built-in display pipeline. Raw numbers: [perf/frame-timing.json](perf/frame-timing.json).

The program drives the real app by itself with **Full animations**: it adds **100 bill lines** (one every 25 ms, faster than a person), types a product search character by character, then flips through **10 pages** (sales register with 20,000 bills, products, customers, reports, estimates, stock, settings, home, money to collect, billing). Frame time = build + raster time of each frame.

| Run | Frames | Average | Median | 95th percentile | 99th | **Worst** | Frames over 16.7 ms | Over 33.4 ms |
|---|---|---|---|---|---|---|---|---|
| Normal | 705 | 6.71 ms | 5.93 ms | **11.46 ms** | 13.78 ms | **27.79 ms** | 2 | 0 |
| Contended (8 busy CPU processes, half of all threads kept at 100%) | 636 | 11.16 ms | 10.13 ms | **19.63 ms** | 22.72 ms | **25.43 ms** | 87 | 0 |

**Budget: worst frame under 33 ms, 95th percentile under 16 ms.**
- Normal: **both met** (worst 27.8 ms, p95 11.5 ms).
- Contended ("throttled" machine): worst frame **met** (25.4 ms), 95th percentile **not met** (19.6 ms, budget 16 ms). Even then the average (11.2 ms) is far from the 22 ms where the auto-protect guard would drop to Gentle, and no frame was over 33 ms.

What we changed because of the first run (it failed the budget: worst frame 119 ms, p95 18.7 ms): the sales register built all 20,000 bills at once when opened. Bills are now built only when they are shown (lazy list) and the reports and sales statistics stop at the first bill outside their range.

**Not verified:** a real low-end PC or tablet, a real shop PC under real use. A true CPU throttle is not possible on this machine, so "contended" means other busy programs, not a slower processor.

Other timing facts (widget tests, `test/motion_test.dart`): scan x20 + Save take effect in the very next frame with animations Off and Full; the wall time of that flow was 1.5 s (Off) and 1.2-1.4 s (Full) in the test harness, i.e. no added waiting.
