// src/AdminBox.sol
pragma solidity ^0.8.19;

// TODO: 1. 从 OpenZeppelin 库中导入 Ownable.sol
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

// TODO: 2. 让 AdminBox 合约继承 Ownable
contract AdminBox is Ownable {
    uint256 public value;

    // TODO: 3. 编写一个 setValue(uint256 _newValue) 函数 - 这个函数必须 *只能* 被合约的 owner 调用
    constructor() Ownable(msg.sender) {}

    function setValue(uint256 _newValue) public onlyOwner {
        value = _newValue;
    }
}

contract AccessBox is AccessControl {
    uint256 public value;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function setValue(uint256 _newValue) public onlyRole(ADMIN_ROLE) {
        value = _newValue;
    }

    function grantAdminRole(address account) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        revokeRole(ADMIN_ROLE, account);
    }
}
