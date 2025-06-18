// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {VrfRaffle} from "../src/utils/VrfRaffle.sol";

contract VrfRaffleScript is Script {
    VrfRaffle public vrfRAffle;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        vrfRAffle = new VrfRaffle();

        vm.stopBroadcast();
    }
}
