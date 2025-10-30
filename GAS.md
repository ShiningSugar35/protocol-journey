## Day 14: Gas Optimization (A) - Storage Packing

[cite_start]Today's objective was to implement and measure the gas costs of different storage packing techniques, as outlined in the Day 14 battle plan[cite: 18].

I created a `GasChallenge.sol` contract and used `forge test --gas-report` to analyze the cost of writing data under three different scenarios:
1.  **Unpacked:** Using separate `uint256` slots (the baseline).
2.  **EVM Auto-Packed:** Using smaller types (`uint64`, `uint128`, `uint64`) and letting the Solidity compiler automatically pack them into a single 32-byte slot.
3.  **Manual Bitwise Packing:** Using bitwise shift operators (`<<`, `|`) to manually pack variables into a single `uint256` slot.

### Forge Gas Report Analysis

The `forge test --gas-report` provided a clear comparison of the gas consumed by the function calls responsible for writing the data.

| Method | Contract | Function | Gas Cost (Avg) |
| :--- | :--- | :--- | ---: |
| **Unpacked (Baseline)** | `UnpackedStorage` | `setValues` | 88,563 |
| **EVM Auto-Packing** | `PackedStorage` | `setValues` | 45,081 |
| **Manual Bitwise Packing** | `PackedStorage` | `packValues` | 44,490 |

*(Note: The test names `test_SetPacked` (50,971 gas) and `test_SetUnpacked` (94,507 gas) reflect the total gas for the test setup *plus* the function call, while the gas report table above isolates the cost of the contract functions themselves.)*

### Key Findings

Based on the gas report and the Rareskills gas optimization tutorial:

1.  **Storage Packing is Critical:** The most significant saving came from moving from unpacked `uint256` variables (each taking one slot) to EVM auto-packed variables (sharing one slot). This saved **43,482 gas** (`88,563` - `45,081`), confirming that minimizing `SSTORE` (storage write) operations is a primary optimization target.

2.  **Manual Packing is the Most Efficient:** As the tutorial hypothesized, manually packing the variables using bitwise operations (`packValues`) was the most gas-efficient method. It saved an additional **591 gas** (`45,081` - `44,490`) compared to letting the EVM handle the packing (`setValues` in `PackedStorage`). This is likely due to the manual method avoiding extra "masking" opcodes that the compiler adds for safety when automatically handling smaller-than-256-bit types.

---

### Raw `forge test --gas-report` Output

<details>
  <summary>Click to expand raw console output</summary>

```bash
hp@DESKTOP-RID5EQJ MINGW64 /d/web3/protocol-journey (feat/week3-day14-gas-packing)
$ forge test --match-path test/GasChallenge.t.sol --gas-report
[⠊] Compiling...
No files changed, compilation skipped

Ran 3 tests for test/GasChallenge.t.sol:GasChallengeTest
[PASS] test_PackValues() (gas: 50403)
[PASS] test_SetPacked() (gas: 50971)
[PASS] test_SetUnpacked() (gas: 94507)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 1.71ms (1.19ms CPU
time)

╭---------------------------------------------+-----------------+-------+-------
-+-------+---------╮
| src/GasChallenge.sol:PackedStorage Contract |                 |       |
 |       |         |
+===============================================================================
===================+
| Deployment Cost                             | Deployment Size |       |
 |       |         |
|---------------------------------------------+-----------------+-------+-------
-+-------+---------|
| 261406                                      | 991             |       |
 |       |         |
|---------------------------------------------+-----------------+-------+-------
-+-------+---------|
|                                             |                 |       |
 |       |         |
|---------------------------------------------+-----------------+-------+-------
-+-------+---------|
| Function Name                               | Min             | Avg   | Median
 | Max   | # Calls |
|---------------------------------------------+-----------------+-------+-------
-+-------+---------|
| packValues                                  | 44490           | 44490 | 44490
 | 44490 | 1       |
|---------------------------------------------+-----------------+-------+-------
-+-------+---------|
| setValues                                   | 45081           | 45081 | 45081
 | 45081 | 1       |
╰---------------------------------------------+-----------------+-------+-------
-+-------+---------╯

╭-----------------------------------------------+-----------------+-------+-----
---+-------+---------╮
| src/GasChallenge.sol:UnpackedStorage Contract |                 |       |
   |       |         |
+===============================================================================
=====================+
| Deployment Cost                               | Deployment Size |       |
   |       |         |
|-----------------------------------------------+-----------------+-------+-----
---+-------+---------|
| 154179                                        | 495             |       |
   |       |         |
|-----------------------------------------------+-----------------+-------+-----
---+-------+---------|
|                                               |                 |       |
   |       |         |
|-----------------------------------------------+-----------------+-------+-----
---+-------+---------|
| Function Name                                 | Min             | Avg   | Medi
an | Max   | # Calls |
|-----------------------------------------------+-----------------+-------+-----
---+-------+---------|
| setValues                                     | 88563           | 88563 | 8856
3  | 88563 | 1       |
╰-----------------------------------------------+-----------------+-------+-----
---+-------+---------╯


Ran 1 test suite in 8.56ms (1.71ms CPU time): 3 tests passed, 0 failed, 0 skippe
d (3 total tests)