The diff is clean and correct. Here's a summary of the rework changes:

---

## Rework Summary

### Root Cause Fixed: Sensor Asymmetry (Blocking Item #3)

The original implementation used `readings[0]` (sensor at −15° relative to robot heading) for both left and right scans. After rotating to the left scan heading (heading + 90°), this sensor pointed at `heading + 75°` instead of `heading + 90°`. After rotating to the right scan heading (heading − 90°), it pointed at `heading − 105°` instead of `heading − 90°`. The left/right scans were thus asymmetric (`75°` vs `−105°`), corrupting the `dist_right − dist_left` error signal used for tunnel-centring.

**Fix:** Added `scanReading()` helper that averages `readings[0]` (−15°) and `readings[1]` (+15°). After rotating to any scan heading, these two sensors point symmetrically at `±15°` around the scan direction. Their average gives a bias-free measurement exactly in the scan direction. This restores the symmetry required for the R4 tunnel-centring formula to produce a zero error signal when the robot is centered.

### Non-Blocking Fixes

- **Trailing newlines:** Added missing trailing newlines to `include/Config.h`, `src/Config.cpp`, and `src/ScenarioSimulation.cpp` (all three files flagged in the review).
- **Explicit `<vector>` include:** Added `#include <vector>` to `WallFollower.cpp` for the `scanReading()` helper's parameter type.