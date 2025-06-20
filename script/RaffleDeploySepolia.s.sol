// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {PriceUtils} from "../src/utils/PriceUtils.sol";

import {VrfRaffle} from "../src/utils/VrfRaffle.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import {SwapERC20ToEthUniSwapV4} from "../src/utils/SwapERC20ToEthUniSwapV4.sol";

import {RaffleErc20} from "../src/core/RaffleErc20.sol";

contract RaffleDeploySepolia is Script {
    ////////
    // Price utils
    PriceUtils public priceUtilsContract;
    address public priceUtilsAddress;

    //////////
    // Vrf chainlink oracle
    VrfRaffle public vrfRAffleContract;
    address public vrfRAffleAddress;
    address public constant vrfWrapperAddress =
        0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1;
    address public constant linkAddress =
        0x779877A7B0D9E8603169DdbD7836e478b4624789;

    //////////
    // Swap contract
    SwapERC20ToEthUniSwapV4 public swapContract;
    address public swapAddress;
    // Sepolia uniswap universal router
    address payable constant uRouter =
        payable(0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b);
    // Sepolia uniswap permit2
    address constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    // Sepolia uniswap poolmanager
    address constant poolManager = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;

    //////////
    // Raffle contract
    RaffleErc20 public raffleContract;
    address public raffleAddress;
    uint8 constant maxTickets = 4;
    uint256 constant prize = 1500000000000000; // 0.0015 eth
    uint256 constant ticketPrice = 500000000000000; //0.0005 eth
    address adminAddress;
    address benefitAddress;
    address taxAddress;
    uint8 constant taxRate = 20; // Classic 20% tax rate
    string constant nameRaffleNFT = "Raffle with Vrf ChainLink";
    string[] tokenURIHashs = [
        "QmTYMZkJB3hmmamegfZfxAeqZCUBCyB4B5hpEdoHLFtynR",
        "QmQBNLAJQjT5aSSRTo1PnDzKu7kgvxFhTKKmwaAMFJmNmA",
        "QmTYMZkJB3hmmamegfZfxAeqZCUBCyB4B5hpEdoHLFtynR",
        "QmQBNLAJQjT5aSSRTo1PnDzKu7kgvxFhTKKmwaAMFJmNmA"
    ];
    address constant _addressVrf = 0xc67f000FEaaBdFb06D049795b4E02174528Eac9C;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY_SEPOLIA");
        address deployerAddress = vm.addr(privateKey);
        adminAddress = deployerAddress;
        benefitAddress = deployerAddress;
        taxAddress = deployerAddress;

        vm.startBroadcast();

        /////////
        // Price utils
        priceUtilsContract = new PriceUtils(poolManager);
        priceUtilsAddress = address(priceUtilsContract);

        //////////
        // Vrf
        vrfRAffleContract = new VrfRaffle(linkAddress, vrfWrapperAddress);
        vrfRAffleAddress = address(vrfRAffleContract);

        // Fund the conctract with 5 Link
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(link.transfer(vrfRAffleAddress, 5 ether), "Unable to transfer");

        //////////
        // Swap contract
        swapContract = new SwapERC20ToEthUniSwapV4(
            uRouter,
            permit2,
            poolManager
        );
        swapAddress = address(swapContract);

        //////////
        // Raffle
        raffleContract = new RaffleErc20(
            maxTickets,
            prize,
            ticketPrice,
            adminAddress,
            benefitAddress,
            taxRate,
            taxAddress,
            nameRaffleNFT,
            tokenURIHashs,
            vrfRAffleAddress,
            swapAddress
        );
        raffleAddress = address(raffleContract);

        // Add raffle contract authorization to request randomwords
        vrfRAffleContract.setAuthorizedAddress(raffleAddress);

        console.log("Price utils deployed at: %s", priceUtilsAddress);
        console.log("Vrf chainlink oracle deployed at: %s", vrfRAffleAddress);
        console.log("Swap deployed at: %s", swapAddress);
        console.log("Raffle deployed at: %s", raffleAddress);

        vm.stopBroadcast();
    }
}
