// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

contract PoolStateReader {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    event PoolState(
        uint160 sqrtPriceX96,
        int24 tick,
        uint256 protocolFee,
        uint256 lpFee
    );

    struct PoolInfo {
        PoolKey key;
        uint160 sqrtPriceX96;
        int24 tick;
        uint24 protocolFee;
        uint24 lpFee;
        uint128 liquidity;
    }

    IPoolManager public immutable poolManager;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    /**
     * Get the tickspacing linked to the fee
     */
    function getTickSpacingFromFee(uint24 fee) internal pure returns (int24) {
        if (fee == 500) return 10;
        if (fee == 3000) return 60;
        if (fee == 10000) return 200;
        revert("Invalid fee");
    }

    function getPoolState(
        PoolKey calldata key
    )
        public
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint24 protocolFee,
            uint24 lpFee
        )
    {
        return poolManager.getSlot0(key.toId());
    }

    /** Get all pool states for a given ERC20 token
     * @param _tokenERC20 The address of the ERC20 token
     * @return poolInfos An array of PoolInfo structs containing the state of each pool with fees 500, 3000, and 10000
     */
    function getPoolStateERC20ToEth(
        address _tokenERC20
    ) public view returns (PoolInfo[] memory poolInfos) {
        // Instanciate the array of PoolInfo structs with a length of 3
        poolInfos = new PoolInfo[](3);

        // Fee 500
        PoolKey memory key = getPoolKey(
            _tokenERC20,
            500,
            getTickSpacingFromFee(500)
        );

        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint24 protocolFee,
            uint24 lpFee
        ) = poolManager.getSlot0(key.toId());

        uint128 liquidity = poolManager.getLiquidity(key.toId());

        poolInfos[0] = PoolInfo({
            key: key,
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            protocolFee: protocolFee,
            lpFee: lpFee,
            liquidity: liquidity
        });

        // Fee 3000
        key = getPoolKey(_tokenERC20, 3000, getTickSpacingFromFee(3000));

        (sqrtPriceX96, tick, protocolFee, lpFee) = poolManager.getSlot0(
            key.toId()
        );

        liquidity = poolManager.getLiquidity(key.toId());

        poolInfos[1] = PoolInfo({
            key: key,
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            protocolFee: protocolFee,
            lpFee: lpFee,
            liquidity: liquidity
        });

        // Fee 10000
        key = getPoolKey(_tokenERC20, 10000, getTickSpacingFromFee(10000));

        (sqrtPriceX96, tick, protocolFee, lpFee) = poolManager.getSlot0(
            key.toId()
        );

        liquidity = poolManager.getLiquidity(key.toId());

        poolInfos[2] = PoolInfo({
            key: key,
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            protocolFee: protocolFee,
            lpFee: lpFee,
            liquidity: liquidity
        });

        return poolInfos;
    }

    /** Create a pool key for a given ERC20 token
     * @param _tokenERC20 The address of the ERC20 token
     * @param _fee The fee tier for the pool
     * @param _tickSpacing The tick spacing for the pool
     * @return poolKey The PoolKey struct for the pool
     */
    function getPoolKey(
        address _tokenERC20,
        uint24 _fee,
        int24 _tickSpacing
    ) private pure returns (PoolKey memory) {
        return
            PoolKey({
                currency0: CurrencyLibrary.ADDRESS_ZERO,
                currency1: Currency.wrap(_tokenERC20),
                fee: _fee,
                tickSpacing: _tickSpacing,
                hooks: IHooks(address(0))
            });
    }

    function emitPoolState(PoolKey calldata key) internal {
        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint24 protocolFee,
            uint24 lpFee
        ) = getPoolState(key);
        emit PoolState(sqrtPriceX96, tick, protocolFee, lpFee);
    }
}
