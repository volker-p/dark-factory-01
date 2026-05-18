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
