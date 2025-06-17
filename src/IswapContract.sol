pragma solidity 0.8.24;

/**
 * @title IswapContract
 * @author Pakish https://github.com/Pakish
 * @notice Interface of the swap contract SwapERC20ToEthUniSwapV4
 */

interface IswapContract {
    function swapErc20ToEth(
        bytes calldata _signature,
        address _tokenOwner,
        address _tokenErc20,
        uint256 _amountErc20In,
        uint256 _minAmountEthOut,
        uint256 _nonce,
        uint256 _deadline,
        uint24 _fee
    ) external returns (uint256);

    function swapErc20ToEthAndTransfer(
        // test msg.sender is still good
        bytes calldata _signature,
        address _tokenOwner,
        address _tokenErc20,
        uint256 _amountErc20In,
        uint256 _minAmountEthOut,
        uint256 _nonce,
        uint256 _deadline,
        uint24 _fee,
        address payable _transferTo
    ) external returns (uint256);
}
