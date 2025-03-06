// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
//import { tickToPrice, Pool } from '@uniswap/v3-core/contracts/libraries/TickMath.sol';
/**
 * Get price from sepolia test net
 */
contract GetPriceUniswap {

    address public constant POOLLINKWETH = 0xA470a353577901AA8cDCb828BB616ef41d58B88a;
    

    constructor()
    {   
    }

    /**
     * Return Link / Eth price in wei
     */
    function getLinkEthPriceWeiWtihSlot0() public view returns (uint256 priceWei)
    {
        // Création de l'interface de pool Uniswap V3
        IUniswapV3Pool pool = IUniswapV3Pool(POOLLINKWETH);
        
        (uint160  sqrtPriceX96,,,,,,) = pool.slot0();
        // Convert to wei price
        return getPriceFromSqrtPriceX96(sqrtPriceX96);
        
    }

    /**
     * Return Link / Eth price in wei
     */
    function getLinkEthPriceWeiWtihTick(uint32 _secondsAgo) public view returns (uint256 priceWei)
    {
        // Création de l'interface de pool Uniswap V3
        IUniswapV3Pool pool = IUniswapV3Pool(POOLLINKWETH);
        
        // On observe les 2 dernières périodes de temps
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 0;  // Prix actuel
        secondsAgos[1] = _secondsAgo; // Prix il y a 10minutes

        // Call observe to get 2 cumilatives ticks at times secondsAgos
        (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulatives) = pool.observe(secondsAgos);
        
        // Calcule la différence entre les ticks pour obtenir le prix
        int24 tickTWAP = int24((tickCumulatives[0] - tickCumulatives[1]) / int56(int256(uint256(_secondsAgo)))); // Safe to convert uint32 to int56

        // Conversion du tick en un prix

         uint256 denominator = 2**18;

        // Calcul de 2^(tick / 2^18), ici tick est divisé par 2^18
        // Multiplier par 2^96 pour obtenir le format Q64.96
        uint160 sqrtPriceX96 = uint160(FullMath.mulDiv(2**int256(tickTWAP), 2**96, denominator));

        return getPriceFromSqrtPriceX96(sqrtPriceX96);
    }

    function getPriceFromSqrtPriceX96(uint160 _sqrtPriceX96) public pure returns (uint256)
    {
        uint256 squarePrice = _sqrtPriceX96*_sqrtPriceX96;
        return FullMath.mulDiv(squarePrice, 1**18, 2**192); 
    }
 

}

