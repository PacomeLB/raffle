// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PriceUtils} from "../src/utils/PriceUtils.sol";

contract PriceUtilsScript is Script {
    PriceUtils public mypriceUtils;

    address constant _poolManager = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        mypriceUtils = new PriceUtils(_poolManager);

        vm.stopBroadcast();
    }
}
