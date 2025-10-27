// src/Delegatecall.sol
pragma solidity ^0.8.19;

// --- 第一个实现合约 ---
contract LogicV1 {
    uint256 public x;
    address public owner;

    function initialize() public {
        owner = msg.sender;
    }

    function setX(uint256 _x) public {
        require(msg.sender == owner, "Not owner");
        x = _x;
    }
}

// --- 第二个实现合约（有存储冲突） ---
contract LogicV2 {
    // 把变量顺序搞反
    address public owner;
    uint256 public x;

    function initialize() public {
        owner = msg.sender;
    }

    function setX(uint256 _x) public {
        require(msg.sender == owner, "Not owner");
        x = _x;
    }
}

// --- 代理合约 ---
contract Proxy {
    address public implementation;
    address public owner;

    constructor(address _implementation) {
        implementation = _implementation;
        owner = msg.sender;
    }

    function upgradeTo(address _newImplementation) public {
        require(msg.sender == owner, "Not owner");
        implementation = _newImplementation;
    }

    fallback() external payable {
        address impl = implementation;
        require(impl != address(0), "Implementation not set");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
