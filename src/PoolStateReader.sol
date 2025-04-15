// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

contract PoolStateReader {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    event PoolState(
        uint160 sqrtPriceX96,
        int24 tick,
        uint256 protocolFee,
        uint256 lpFee
    );

    IPoolManager public immutable poolManager;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    function getPoolState(PoolKey calldata key) public view returns (
    uint160 sqrtPriceX96,
    int24 tick,
    uint24 protocolFee,
    uint24 lpFee){
    
        return poolManager.getSlot0(key.toId());
    }

    function emitPoolState(PoolKey calldata key) internal {
        (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = getPoolState(key);
        emit PoolState(sqrtPriceX96, tick, protocolFee, lpFee);
    }
}