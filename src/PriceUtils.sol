// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolStateReader} from "./PoolStateReader.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract PriceUtils is PoolStateReader {
    constructor(
        address _poolManager
    ) PoolStateReader(IPoolManager(_poolManager)) {}

    struct PriceInfo {
        address tokenERC20;
        uint8 decimals;
        uint256 priceWei;
        uint24 feeTier;
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

        minAmountIn = FullMath.mulDiv(
            amountInWithoutFees,
            1000000,
            1000000 - totalFees
        );

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

    function getMinAmountInFromErc20ToEth(
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
                priceWei: minAmountIn,
                feeTier: poolinfo[i].lpFee
            });
        }
    }
}
