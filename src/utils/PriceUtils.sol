// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolStateReader} from "./PoolStateReader.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {FixedPoint96} from "v4-core/libraries/FixedPoint96.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Console logging for debugging
import {console} from "forge-std/console.sol";

/**
 * @title Contract for calculating prices and amounts in Uniswap V4 pools
 * @author Pacome LEBEAU https://github.com/PacomeLB
 * @notice Allows users calculate the minimum amount of an ERC20 token to swap to receive a certain amount of ETH. Get the best pool based on the price and liquidity.
 * @dev Uses Uniswap V4 pool state to calculate prices and amounts
 */
contract PriceUtils is PoolStateReader {
    constructor(
        address _poolManager
    ) PoolStateReader(IPoolManager(_poolManager)) {}

    uint16 public constant MAX_LIQUIDITY_CHANGE = 2000; // max of 2% in %%%% change in liquidity

    struct PriceInfo {
        address tokenERC20;
        uint8 decimals; // Decimals of the ERC20 token
        uint256 tokenAmountDecimals; // Price in wei (or decimals of the token)
        uint24 feeTier; // Fee tier for the pool in (1/1 000 000)
        LiquidityInfo liquidity;
    }

    struct LiquidityInfo {
        uint256 ethLiquidity; // Approximate liquidity in ETH wei
        uint256 erc20Liquidity; // Approximate liquidity in ERC20 token decimals
    }

    /**
     * Calculate minimum amount of an ERC20 token to swap to receive a certain amount of ETH
     * Add a 1% of slippage tolerance
     * @param _amountEthWei min amount of eth to received in wei
     * @param _price price of the pairs in wei
     * @param _fees the fee tier for the pool in (1/1 000 000)
     * @return minAmountIn the minimum amount of the ERC20 token to swap in wei or decimals of the token
     */
    function calculateAmountIn(
        uint256 _amountEthWei,
        uint256 _price,
        uint24 _fees,
        uint8 _decimals
    ) public pure returns (uint256 minAmountIn) {
        require(_price > 0, "Price must be greater than 0");
        require(_amountEthWei > 0, "Amount must be greater than 0");
        require(_fees > 0, "Fees must be greater than 0");
        uint24 totalFees = _fees + 10000; // Add slippage tolerance 1%
        uint256 amountInWithoutFees = FullMath.mulDiv(
            _amountEthWei,
            _price,
            10 ** (_decimals + 18)
        );
        console.log("amountInWithoutFees: %s", amountInWithoutFees);

        minAmountIn = FullMath.mulDiv(
            amountInWithoutFees,
            1000000,
            1000000 - totalFees
        );

        console.log("minAmountIn with fees: %s", minAmountIn);

        return minAmountIn;
    }

    /**
     * Convert a Uniswap V4 sqrt price to a price in wei
     * @param _sqrtPriceX96 the sqrt price in X96 format
     * @param _decimals the number of decimals for the token
     */
    function getPriceFromSqrtPriceX96(
        uint160 _sqrtPriceX96,
        uint8 _decimals
    ) public pure returns (uint256) {
        require(_sqrtPriceX96 > 0, "Sqrt price must be greater than 0");
        require(_sqrtPriceX96 < 2 ** 192, "Sqrt price too high");
        require(_decimals > 0, "Decimals must be greater than 0");
        require(_decimals <= 18, "Decimals must be less than or equal to 18");

        uint256 squarePrice = uint256(_sqrtPriceX96) * uint256(_sqrtPriceX96);
        // 10**_decimals is used to adjust the price to the correct decimal places
        return FullMath.mulDiv(squarePrice, 10 ** (_decimals + 18), 2 ** 192);
    }

    /**
     * @notice Get PriceInfo array with pool info for a minimum amount of an ERC20 token to swap to receive a certain amount of ETH
     * @param _tokenERC20 the address of the ERC20 token
     * @param _amountEthWei the minimum amount of ETH to receive in wei
     * @return priceInfos an array of PriceInfo structs containing the minimum amount of the ERC20 token to swap
     * PriceInfo {address tokenERC20;uint8 decimals; uint256 tokenAmountDecimals; uint24 feeTier;}
     */
    function getSwapPriceInfoForMinAmountInFromErc20ToEth(
        address _tokenERC20,
        uint256 _amountEthWei
    ) public view returns (PriceInfo[] memory priceInfos) {
        priceInfos = new PriceInfo[](3);

        uint8 decimals = IERC20Metadata(_tokenERC20).decimals();

        PoolInfo[] memory poolinfo = getPoolStateERC20ToEth(_tokenERC20);
        for (uint8 i = 0; i <= 2; i++) {
            uint256 price = getPriceFromSqrtPriceX96(
                poolinfo[i].sqrtPriceX96,
                decimals
            );

            uint256 minAmountIn = calculateAmountIn(
                _amountEthWei,
                price,
                poolinfo[i].lpFee,
                decimals
            );

            priceInfos[i] = PriceInfo({
                tokenERC20: _tokenERC20,
                decimals: decimals,
                tokenAmountDecimals: minAmountIn,
                feeTier: poolinfo[i].lpFee,
                liquidity: getTokenLiquidity(poolinfo[i])
            });
        }
    }

    /**
     * @notice Get the approximate liquidity of a Uniswap V4 pool
     * @param _poolInfo the PoolInfo struct containing the state of the pool
     * @return liquidityInfo a LiquidityInfo struct containing the liquidity in ETH wei and ERC20 token decimals
     */
    function getTokenLiquidity(
        PoolInfo memory _poolInfo
    ) public pure returns (LiquidityInfo memory liquidityInfo) {
        // Approximate Eth (token0) liquidity
        uint256 ethLiquidity = FullMath.mulDiv(
            _poolInfo.liquidity,
            FixedPoint96.Q96,
            _poolInfo.sqrtPriceX96
        );
        // Approximate ERC20 (token1) liquidity
        uint256 erc20Liquidity = FullMath.mulDiv(
            _poolInfo.liquidity,
            _poolInfo.sqrtPriceX96,
            FixedPoint96.Q96
        );

        liquidityInfo = LiquidityInfo({
            ethLiquidity: ethLiquidity,
            erc20Liquidity: erc20Liquidity
        });

        return liquidityInfo;
    }

    /**
     * @notice Select the best pool based on the price and liquidity
     * @param _priceInfos an array of PriceInfo structs containing the price and liquidity of each pool
     * @param _amountEthWei the minimum amount of ETH to receive in wei
     * @return selectedPriceInfo the PriceInfo struct of the selected pool
     */
    function selectPool(
        PriceInfo[] memory _priceInfos,
        uint256 _amountEthWei
    ) public pure returns (PriceInfo memory selectedPriceInfo) {
        uint8 bestPoolIndex = 0;
        bool[] memory isValidPool = new bool[](_priceInfos.length);
        bool isOneValidPool = false;

        // Calculate % of liquidity change for each pool
        for (uint8 i = 0; i < _priceInfos.length; i++) {
            console.log("############ Pool %s ############", i);
            if (
                _priceInfos[i].liquidity.erc20Liquidity == 0 ||
                _priceInfos[i].liquidity.ethLiquidity == 0
            ) {
                console.log("Liquidity pool has zero liquidity, skipping", i);
                isValidPool[i] = false; // Mark pool as invalid
                continue; // Skip pools with zero liquidity
            }

            uint256 liquidityErc20AmountChange = FullMath.mulDiv(
                _priceInfos[i].tokenAmountDecimals,
                100000,
                _priceInfos[i].liquidity.erc20Liquidity
            );

            console.log(
                "Liquidity pool ERC20: %s",
                _priceInfos[i].liquidity.erc20Liquidity
            );
            console.log(
                "Amount of ERC20 to swap: %s",
                _priceInfos[i].tokenAmountDecimals
            );
            console.log(
                "Liquidity use ERC20 amount Change : %s (1000%)",
                liquidityErc20AmountChange
            );

            uint256 liquidityEthAmountChange = FullMath.mulDiv(
                _amountEthWei,
                100000,
                _priceInfos[i].liquidity.ethLiquidity
            );
            console.log(
                "Liquidity pool ETH amount Change: %s",
                _priceInfos[i].liquidity.ethLiquidity
            );
            console.log("Amount of Eth to swap: %s", _amountEthWei);
            console.log(
                "Liquidity use ETH amount Change: %s (1000%)",
                liquidityEthAmountChange
            );

            // Save the valid pool if liquidity change is within the limit
            if (
                liquidityErc20AmountChange > MAX_LIQUIDITY_CHANGE ||
                liquidityEthAmountChange > MAX_LIQUIDITY_CHANGE
            ) {
                isValidPool[i] = false; // pool liquidity change is too high
            } else {
                // Set price of the pool if liquidity change is valid
                bestPoolIndex = i; // Initialize best pool index
                isValidPool[i] = true; // At least one valid pool found
                isOneValidPool = true; // Set flag to true if at least one valid pool is found
                console.log("We have a valid pool: %s", i);
            }

            console.log("########################");
        }

        // Find the best pool based on the price with a valid liquidity
        for (uint8 i = 0; i < _priceInfos.length; i++) {
            if (!isValidPool[i]) continue; // Skip invalid pools
            for (uint8 j = i + 1; j < _priceInfos.length; j++) {
                if (!isValidPool[j]) continue; // Skip invalid pools
                console.log(
                    "Comparing pool %i amount %i",
                    i,
                    _priceInfos[i].tokenAmountDecimals
                );
                console.log(
                    "With pool %i amount %i",
                    j,
                    _priceInfos[j].tokenAmountDecimals
                );

                if (
                    _priceInfos[i].tokenAmountDecimals <=
                    _priceInfos[j].tokenAmountDecimals
                ) {
                    bestPoolIndex = i; // Update best pool index if a better pool is found
                } else {
                    bestPoolIndex = j; // Update best pool index if a better pool is found
                }
            }
        }

        console.log(
            "Best pool index is now %i with amount %i(wei) to send to receive %s ETH(wei)",
            bestPoolIndex,
            _priceInfos[bestPoolIndex].tokenAmountDecimals,
            _amountEthWei
        );

        // // No pool are in the range of liquidity change, so we select the best pool based on the price and with enough liquidity
        // if (!isOneValidPool) {
        //     for (uint8 i = 0; i < _priceInfos.length; i++) {
        //         if (
        //             _priceInfos[i].liquidity.ethLiquidity == 0 ||
        //             _priceInfos[i].liquidity.erc20Liquidity == 0
        //         ) {
        //             console.log(
        //                 "Liquidity pool %i has zero liquidity for Eth and/or erc20, skipping",
        //                 i
        //             );
        //             continue; // Skip pools with zero liquidity
        //         }
        //         for (uint8 j = i + 1; j < _priceInfos.length; j++) {
        //             if (
        //                 _priceInfos[j].liquidity.ethLiquidity == 0 ||
        //                 _priceInfos[j].liquidity.erc20Liquidity == 0
        //             ) {
        //                 console.log(
        //                     "Liquidity pool %i has zero liquidity for Eth and/or erc20, skipping",
        //                     j
        //                 );
        //                 continue; // Skip pools with zero liquidity
        //             }
        //             if (
        //                 _priceInfos[i].tokenAmountDecimals <=
        //                 _priceInfos[j].tokenAmountDecimals
        //             ) {
        //                 bestPoolIndex = i; // Update best pool index if a better pool is found
        //             }
        //         }
        //     }
        // }

        // If no valid pool was found, we can accept this token
        require(
            isOneValidPool,
            "No valid pool found, we cannot accept this token!"
        );

        return _priceInfos[bestPoolIndex];
    }

    /**
     * @notice Give the best pool to swap an ERC20 token to receive a certain amount of ETH
     * @param _tokenERC20 The address of the ERC20 token
     * @param _amountEthWei The minimum amount of ETH to receive in wei
     * @return selectedPriceInfo The PriceInfo struct of the selected pool
     * PriceInfo {address tokenERC20;uint8 decimals; uint256 tokenAmountDecimals; uint24 feeTier;}
     */
    function getBestPool(
        address _tokenERC20,
        uint256 _amountEthWei
    ) public view returns (PriceInfo memory selectedPriceInfo) {
        PriceInfo[]
            memory priceInfos = getSwapPriceInfoForMinAmountInFromErc20ToEth(
                _tokenERC20,
                _amountEthWei
            );

        return selectPool(priceInfos, _amountEthWei);
    }
}
