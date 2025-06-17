// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SwapERC20ToEthUniSwapV4} from "../src/utils/SwapERC20ToEthUniSwapV4.sol";

contract SwapERC20ToEthUniSwapV4Script is Script {
    SwapERC20ToEthUniSwapV4 public myswapERC20ToEthUniSwapV4;

    // Sepolia uniswap universal router
    address payable constant _Urouter =
        payable(0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b);
    // Sepolia uniswap permit2
    address constant _permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    address constant _poolManager = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        myswapERC20ToEthUniSwapV4 = new SwapERC20ToEthUniSwapV4(
            _Urouter,
            _permit2,
            _poolManager
        );

        vm.stopBroadcast();
    }
}
