// test/AccessControl.t.sol
pragma solidity ^0.8.19;

import "lib/forge-std/src/Test.sol";
import "src/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract AccessControlTest is Test {
    address private owner = address(this); // 测试合约自己是 owner
    address private nobody = makeAddr("nobody"); // 模拟一个路人
    address private anotherAdmin = makeAddr("anotherAdmin"); // 另一个管理员

    // --- Part 1: 测试 AdminBox (Ownable) ---

    AdminBox private box;

    function setUp_AdminBox() public {
        vm.prank(owner); // 确保部署者是 owner
        box = new AdminBox();
    }

    // TODO: 1. 编写测试 `test_OwnerCanSetValue()`- 证明: owner 可以成功调用 setValue
    function test_OwnerCanSetValue() public {
        setUp_AdminBox();
        uint256 newValue = 42;
        vm.prank(owner);
        box.setValue(newValue);
        assertEq(box.value(), newValue);
    }

    // TODO: 2. 编写测试 `test_NonOwnerCannotSetValue()`
    function test_NonOwnerCannotSetValue() public {
        setUp_AdminBox();
        uint256 newValue = 100;
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nobody));
        box.setValue(newValue);
    }

    // --- Part 2: 【附加挑战】测试 AccessBox (AccessControl) ---

    AccessBox private accessBox;
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function setUp_AccessBox() public {
        vm.prank(owner); // 确保部署者是 owner
        accessBox = new AccessBox();
    }

    // TODO: 3. 编写测试 `test_RoleAdminCanSetValue()` - 证明: 拥有 ADMIN_ROLE 的 owner 可以成功调用 setValue
    function test_RoleAdminCanSetValue() public {
        setUp_AccessBox();
        vm.prank(owner);
        uint256 newValue = 55;
        accessBox.setValue(newValue);
        assertEq(accessBox.value(), newValue);
    }

    // TODO: 4. 编写测试 `test_NonRoleAdminCannotSetValue()`- 证明: nonOwner (路人) 调用 setValue 会失败 (revert)
    function test_NonRoleAdminCannotSetValue() public {
        setUp_AccessBox();
        vm.prank(nobody);
        uint256 newValue = 77;
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, nobody, ADMIN_ROLE)
        );
        accessBox.setValue(newValue);
    }

    // TODO: 5. 编写测试 `test_GrantAndRevokeRole()`
    function test_GrantAndRevokeRole() public {
        // --- 授权 ---
        // 1. (Prank as Owner) 调用 grantAdminRole 授权给 anotherAdmin
        // 2. 断言 `accessBox.hasRole(ADMIN_ROLE, anotherAdmin)` 为 true
        setUp_AccessBox();
        vm.prank(owner);
        accessBox.grantAdminRole(anotherAdmin);
        assertTrue(accessBox.hasRole(ADMIN_ROLE, anotherAdmin));

        // --- 验证新授权 ---
        // 3. (Prank as anotherAdmin) 调用 setValue
        // 4. 断言 value 被成功设置
        vm.prank(anotherAdmin);
        uint256 newValue = 88;
        accessBox.setValue(newValue);
        assertEq(accessBox.value(), newValue);

        // --- 撤销 ---
        // 5. (Prank as Owner) 调用 revokeAdminRole 撤销 anotherAdmin 的权限
        // 6. 断言 `accessBox.hasRole(ADMIN_ROLE, anotherAdmin)` 为 false
        vm.prank(owner);
        accessBox.revokeAdminRole(anotherAdmin);
        assertFalse(accessBox.hasRole(ADMIN_ROLE, anotherAdmin));

        // --- 验证撤销 ---
        // 7. (Prank as anotherAdmin) 再次调用 setValue
        // 8. 使用 vm.expectRevert 断言调用失败
        vm.prank(anotherAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, anotherAdmin, ADMIN_ROLE)
        );
        accessBox.setValue(99);

        vm.prank(anotherAdmin);
        vm.expectRevert("Caller is not an admin");
        accessBox.grantAdminRole(nobody);

        vm.prank(anotherAdmin);
        vm.expectRevert("Caller is not an admin");
        accessBox.revokeAdminRole(owner);
    }
}
