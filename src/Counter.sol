// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Counter {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }

    function decrement() public {
        require(number >= 1, unicode"你这个数太小了，没法再减了！");
        number--;
    }

    function forGitFlow() private {}
}
