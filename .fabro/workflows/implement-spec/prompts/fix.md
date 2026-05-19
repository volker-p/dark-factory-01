The test suite failed. Fix the failures without breaking passing tests.

## Steps

1. Read the test output from the previous step carefully.
2. Identify the root cause of each failure — do not guess; trace through the code.
3. Fix one failure class at a time. Verify your reasoning before changing code.
4. Rules:
   - Do not rewrite working code
   - Do not add workarounds — fix the actual problem
   - Do not remove tests to make them pass
   - Do not weaken assertions
5. After fixing, commit your changes:
   ```bash
   cd target-repo
   git add -A
   git commit -m "Fix: <one-line description of what was fixed>"
   ```

The test suite will run again automatically after this step.

## Scenario-test failures: use the trace

When a scenario test fails (the SUCCESS column shows `NO`, or the binary exits
non-zero during a `--scenario` run), generate a trajectory trace before
attempting any fix:

```bash
cd target-repo
./cmake-build-debug/SimulationPathFinder \
    --scenario <failing_scenario_name> \
    --trace /tmp/trace_<scenario>.csv
```

Use the lowercase-underscore form of the scenario name (e.g. `straight_tunnel`,
`corner_right`). If the suite as a whole fails, run each failing scenario
individually.

Then read the trace:

```bash
# First collision step
grep ",1$" /tmp/trace_<scenario>.csv | head -5

# First step where robot lost all walls
grep ",NO_WALL," /tmp/trace_<scenario>.csv | head -5

# 10 steps around the first collision
FIRST=$(grep -n ",1$" /tmp/trace_<scenario>.csv | head -1 | cut -d: -f1)
sed -n "$((FIRST-5)),$((FIRST+5))p" /tmp/trace_<scenario>.csv
```

Include your findings in the fix: what step the problem first appeared, what
sensor readings and decision were made at that step, and what the root cause is.
Do not guess — trace through the CSV and the code logic before changing anything.
