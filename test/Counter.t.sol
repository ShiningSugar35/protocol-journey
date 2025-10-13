// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Counter} from "../src/Counter.sol";

contract CounterTest is Test {
    Counter public counter;

    function setUp() public {
        counter = new Counter();
        counter.setNumber(0);
    }

    function testIs0() public view{
        assertEq(counter.number(),0);
    }

    function test_Increment() public {
        counter.increment();
        assertEq(counter.number(), 1);
    }
    
    function test_Decrement() public {
        counter.setNumber(1);
        counter.decrement();
        assertEq(counter.number(), 0);
    }
    
    function test_Revert_WhenDecrementingZero() public{
        counter.setNumber(0);
        vm.expectRevert(unicode"你这个数太小了，没法再减了！");
        counter.decrement();
    }

    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
