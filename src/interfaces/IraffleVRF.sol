// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/**
 * @title IraffleVRF
 * @author Pacome LEBEAU https://github.com/PacomeLB
 * @notice Interface of the VrfRaffle contract that use chainlink Oracle
 */
interface IraffleVRF {
    function requestRandomWords(
        bool enableNativePayment
    ) external returns (uint256);

    function getRequestStatus(
        uint256 _requestId
    )
        external
        view
        returns (uint256 paid, bool fulfilled, uint256[] memory randomWords);
}
