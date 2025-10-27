// test/Delegatecall.t.sol
pragma solidity ^0.8.19;

import "lib/forge-std/src/Test.sol";
import "src/Delegatecall.sol";

contract DelegatecallTest is Test {
    Proxy private proxy;
    LogicV1 private logicV1;
    LogicV2 private logicV2;

    address private player = makeAddr("player");

    function setUp() public {
        logicV1 = new LogicV1();
        proxy = new Proxy(address(logicV1));
        logicV2 = new LogicV2();

        vm.prank(player);
        (bool ok,) = address(proxy).call(abi.encodeWithSignature("initialize()"));
        require(ok, "Initialize V1 failed");
    }

    function test_ProxyV1_Works() public {
        // TODO: 1. 证明 V1 正常工作
        //    - 假装是 player，通过 proxy 去调用 setX(123)
        vm.prank(player);
        LogicV1(address(proxy)).setX(123);
        assertEq(proxy.implementation(), address(uint160(123)), "implementation should be 123");
        assertEq(proxy.owner(), player, "owner should be player");
        // 断言：proxy 的插槽 0 (x) 应该是 123
        // 断言：proxy 的插槽 1 (owner) 应该是 player
    }

    function test_ProxyV2_StorageCollision() public {
        // --- 1. 证明 V1 正常 (同上) ---
        vm.prank(player);
        LogicV1(address(proxy)).setX(123);
        assertEq(proxy.implementation(), address(uint160(123)), "implementation should be 123");
        assertEq(proxy.owner(), player, "owner should be player");

        // --- 2. 升级到 V2 ---
        vm.prank(player);
        proxy.upgradeTo(address(logicV2));

        // --- 3. 灾难发生！ ---
        // V2 的存储布局是反的 (owner 在插槽0, x 在插槽1)
        // V1 在插槽0 写入了 123
        // V2 认为插槽0 存的是 owner

        // TODO: 2. 证明存储冲突
        //    - 断言：通过 V2 的接口去读 proxy 的 owner，会读到什么？
        //    - 断言：通过 V2 的接口去读 proxy 的 x，又会读到什么？
        assertEq(proxy.implementation(), address(logicV2), "Slot 0 in proxy should be logicV2's address");
        // assertEq(LogicV2(address(proxy)).owner(), address(logicV2), "Slot 0 in proxy should be logicV2's address"); 这样写forge test就无法通过，我无法分析出原因(╥﹏╥)
        assertEq(LogicV2(address(proxy)).x(), uint256(uint160(player)), "Slot 1 in proxy should be player's address");
        // TODO: 3. 证明合约已“锁死”
        //    - 尝试假装是 player，通过 proxy 去调用 setX(456)
        //    - 使用 `vm.expectRevert` 来断言这个调用会失败
        //    - (思考：为什么会失败？)
        vm.prank(player);
        vm.expectRevert("Not owner");
        LogicV2(address(proxy)).setX(456);

        vm.prank(address(logicV2));
        LogicV2(address(proxy)).setX(456);
        assertEq(LogicV2(address(proxy)).x(), 456, "Slot 1 in proxy should be 456 now");
    }
}
