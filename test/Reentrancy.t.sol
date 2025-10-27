// test/Reentrancy.t.sol
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";
import "../src/Reentrancy.sol";

contract ReentrancyTest is Test {
    UnsafeEtherVault private unSafeVault;
    SafeEtherVault private SafeVault;
    Attacker private attacker;

    address private player = makeAddr("player"); // 模拟一个普通用户
    uint256 private constant VAULT_DEPOSIT = 10 ether;
    uint256 private constant ATTACKER_DEPOSIT = 1 ether;

    // --- 测试 1: 攻击不安全的金库 ---
    function test_AttackUnsafeVault() public {
        // --- 准备 (Arrange) ---
        unSafeVault = new UnsafeEtherVault();

        // 1. 金库里先存 10 ETH
        vm.deal(address(unSafeVault), VAULT_DEPOSIT);

        // 2. 实例化攻击者，并给它 1 ETH 去发起攻击
        vm.prank(player); // 假装是 player 在部署攻击合约
        attacker = new Attacker(address(unSafeVault));
        vm.deal(address(attacker), ATTACKER_DEPOSIT);

        // TODO:
        attacker.attack{value: ATTACKER_DEPOSIT}();
        attacker.drain();

        assertEq(unSafeVault.getBalance(), 0);
        assertGt(player.balance, VAULT_DEPOSIT);
    }

    // --- 测试 2: 攻击安全的金库 ---
    function test_AttackSafeVault() public {
        // --- 准备 (Arrange) ---
        SafeVault = new SafeEtherVault();

        // 1. 金库里同样存 10 ETH
        vm.deal(address(SafeVault), VAULT_DEPOSIT);

        // TODO:
        vm.prank(player); // 假装是 player 在部署攻击合约
        attacker = new Attacker(address(SafeVault));
        attacker.attack{value: ATTACKER_DEPOSIT}();
        attacker.drain();
        assertEq(SafeVault.getBalance(), 10 ether);
        assertEq(player.balance, ATTACKER_DEPOSIT);
    }
}
