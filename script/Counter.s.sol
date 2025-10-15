// script/Counter.s.sol
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Counter} from "../src/Counter.sol";

contract DeployCounter is Script {
    function run() external returns (Counter) {
        // 开启一个“广播”，之后的所有交易都会被发送到链上
        vm.startBroadcast();

        // 部署 Counter 合约
        Counter counter = new Counter();

        // 结束广播
        vm.stopBroadcast();

        // 返回部署好的合约实例
        return counter;
    }
}
