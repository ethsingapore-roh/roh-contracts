// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Contract.sol";

contract DeployROHGame is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("");
        //USDC testnet address
        address usdcTokenAddress = vm.envAddress("0xa983fecbed621163");

        vm.startBroadcast(deployerPrivateKey);

        ROHGame rohGame = new ROHGame(usdcTokenAddress);

        vm.stopBroadcast();

        console.log("ROHGame deployed at:", address(rohGame));
    }
}
