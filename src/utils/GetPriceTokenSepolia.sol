// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;


import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * Get price from sepolia test net
 */
contract GetPriceTokenSepolia {

    AggregatorV3Interface internal linkEthPrice = AggregatorV3Interface(0x42585eD362B3f1BCa95c640FdFf35Ef899212734);
    AggregatorV3Interface internal ethUsdPrice = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    //Add more data feed here 

    constructor()
    {   
    }


    /**
     * Return Link / Eth price in wei
     */
    function getLinkEthPriceWei() public view returns (uint256 priceWei)
    {
        uint8 decimals = linkEthPrice.decimals();

        (
            , //uint80 roundId
            int256 priceDataFeed,
            ,//uint256 startedA,
            ,//uint256 updatedAt
            //uint80 answeredInRound
        ) = linkEthPrice.latestRoundData();
        
        // Return price in Wei
        return (uint256(priceDataFeed) * 10**(18 - decimals));
    }

    /**
     * Return Eth / USD price in wei
     */
    function getEthUsdPriceWei() internal view returns (uint256 priceWei)
    {
        uint8 decimals = ethUsdPrice.decimals();

        (
            , //uint80 roundId
            int256 priceDataFeed,
            ,//uint256 startedA,
            ,//uint256 updatedAt
            //uint80 answeredInRound
        ) = ethUsdPrice.latestRoundData();
        
        // Return price in Wei
        return (uint256(priceDataFeed) * 10**(18 - decimals));
    }

}

