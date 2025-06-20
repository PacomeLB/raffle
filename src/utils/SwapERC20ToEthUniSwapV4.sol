// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {UniversalRouter} from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import {Commands} from "@uniswap/universal-router/contracts/libraries/Commands.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IV4Router} from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {IPermit2} from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import {ISignatureTransfer} from "@uniswap/permit2/src/interfaces/ISignatureTransfer.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {PoolStateReader} from "./PoolStateReader.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {console} from "forge-std/console.sol";

/**
 * @title Contract for swaping Erc20 token to Eth with uniswapV4
 * @author Pakish https://github.com/Pakish
 * @notice Allow user to swap Erc20 token to Eth via uniswapV4
 * @dev Uses Uniswap V4 pool state to calculate prices and amounts
 */
contract SwapERC20ToEthUniSwapV4 is PoolStateReader, ReentrancyGuard, Ownable {
    using StateLibrary for IPoolManager;

    UniversalRouter public immutable router;
    IPermit2 public immutable permit2;

    error WithdrawErc20TokenError(string message, address erc20Token);
    error SendSwappedEthError(string message, uint256 ethAmount, address to);

    event SwapedErc20Token(
        address erc20Token,
        uint256 amountErc20In,
        uint256 amountEth
    );

    constructor(
        address payable _router,
        address _permit2,
        address _poolManager
    ) PoolStateReader(IPoolManager(_poolManager)) Ownable(msg.sender) {
        router = UniversalRouter(_router);
        permit2 = IPermit2(_permit2);
    }

    /**
     * @dev Performs a token swap using Permit2 for gasless approval
     * @param _signature The EIP712 signature for Permit2 authorization
     * @param _tokenOwner The address of the token owner initiating the swap
     * @param _tokenErc20 The address of the ERC20 token to swap
     * @param _amountErc20In The exact amount of ERC20 tokens to swap
     * @param _minAmountEthOut The minimum amount of ETH to receive (slippage protection)
     * @param _nonce The unique nonce value for this signature
     * @param _deadline The expiration timestamp of the signature (UNIX timestamp)
     * @param _fee The fee tier for the liquidity pool (in basis points, e.g., 3000 = 0.3%)
     * @return amountEthOut The actual amount of ETH received from the swap
     */
    function _swapErc20ToEth(
        bytes calldata _signature,
        address _tokenOwner,
        address _tokenErc20,
        uint256 _amountErc20In,
        uint256 _minAmountEthOut,
        uint256 _nonce,
        uint256 _deadline,
        uint24 _fee
    ) internal returns (uint256) {
        // Call the permit2 contract to transfer the tokens in the contract

        console.log("In swap");

        permit2.permitTransferFrom(
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: _tokenErc20,
                    amount: _amountErc20In
                }),
                nonce: _nonce,
                deadline: _deadline
            }),
            ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: _amountErc20In
            }),
            _tokenOwner,
            _signature
        );

        console.log("Transfer from");

        approveTokenWithPermit2(
            _tokenErc20,
            uint160(_amountErc20In),
            uint48(_deadline)
        );

        console.log("Approved");

        uint256 amountOut = swapExactInputSingleTokenToEth(
            PoolKey({
                currency0: Currency.wrap(address(0)),
                currency1: Currency.wrap(_tokenErc20),
                fee: _fee,
                tickSpacing: getTickSpacingFromFee(_fee),
                hooks: IHooks(address(0))
            }),
            uint128(_amountErc20In),
            uint128(_minAmountEthOut),
            block.timestamp + 5 minutes // 5 minutes to execute the swap
        );

        emit SwapedErc20Token(_tokenErc20, _amountErc20In, amountOut);

        return amountOut;
    }

    /**
     * @notice Swaps an ERC20 token to ETH using a Permit2 signature. External visibility
     * @dev Performs a token swap using Permit2 for gasless approval
     * @param _signature The EIP712 signature for Permit2 authorization
     * @param _tokenOwner The address of the token owner initiating the swap
     * @param _tokenErc20 The address of the ERC20 token to swap
     * @param _amountErc20In The exact amount of ERC20 tokens to swap
     * @param _minAmountEthOut The minimum amount of ETH to receive (slippage protection)
     * @param _nonce The unique nonce value for this signature
     * @param _deadline The expiration timestamp of the signature (UNIX timestamp)
     * @param _fee The fee tier for the liquidity pool (in basis points, e.g., 3000 = 0.3%)
     * @return amountEthOut The actual amount of ETH received from the swap
     */
    function swapErc20ToEth(
        bytes calldata _signature,
        address _tokenOwner,
        address _tokenErc20,
        uint256 _amountErc20In,
        uint256 _minAmountEthOut,
        uint256 _nonce,
        uint256 _deadline,
        uint24 _fee
    ) external returns (uint256) {
        return
            _swapErc20ToEth(
                _signature,
                _tokenOwner,
                _tokenErc20,
                _amountErc20In,
                _minAmountEthOut,
                _nonce,
                _deadline,
                _fee
            );
    }

    /**
     * @notice Swaps an ERC20 token to ETH using a Permit2 signature
     * @dev Performs a token swap using Permit2 for gasless approval
     * @param _signature The EIP712 signature for Permit2 authorization
     * @param _tokenOwner The address of the token owner initiating the swap
     * @param _tokenErc20 The address of the ERC20 token to swap
     * @param _amountErc20In The exact amount of ERC20 tokens to swap
     * @param _minAmountEthOut The minimum amount of ETH to receive (slippage protection)
     * @param _nonce The unique nonce value for this signature
     * @param _deadline The expiration timestamp of the signature (UNIX timestamp)
     * @param _fee The fee tier for the liquidity pool (in basis points, e.g., 3000 = 0.3%)
     * @param _transferTo address to transfer the swapped eth
     * @return swappedAmountEth The actual amount of ETH received from the swap and sent to _transferTo
     */
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
    ) external nonReentrant returns (uint256) {
        uint256 swappedAmountEth = _swapErc20ToEth(
            _signature,
            _tokenOwner,
            _tokenErc20,
            _amountErc20In,
            _minAmountEthOut,
            _nonce,
            _deadline,
            _fee
        );

        (bool success, ) = _transferTo.call{value: swappedAmountEth}("");
        if (!success) {
            revert SendSwappedEthError(
                "Impossible to send swapped eth",
                swappedAmountEth,
                _transferTo
            );
        }

        return swappedAmountEth;
    }

    /**
     * @dev Allow user to swap Erc20 token to Eth via uniswapV4 with an exact input
     * @return uint256  The amount out of eth swaped
     */
    function swapExactInputSingleTokenToEth(
        PoolKey memory _key, // PoolKey struct that identifies the v4 pool
        uint128 _amountIn, // Exact amount of tokens to swap
        uint128 _minAmountOut, // Minimum amount of output tokens expected
        uint256 _deadline // Timestamp after which the transaction will revert
    ) internal returns (uint256) {
        console.log("swapExactInputSingleTokenToEth");

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));

        // Encode V4Router actions
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        bytes[] memory params = new bytes[](3);

        // First parameter: swap configuration
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: _key,
                zeroForOne: false, // false we want to swap token1 to eth (0x0000000000000000000000000000000000000000) address(Token0) < address(Token1) ALWAYS
                amountIn: _amountIn, // amount of tokens we're swapping
                amountOutMinimum: _minAmountOut, // minimum amount we expect to receive
                hookData: bytes("") // no hook data needed
            })
        );

        // Second parameter: specify input tokens for the swap
        // encode SETTLE_ALL parameters
        params[1] = abi.encode(_key.currency1, _amountIn);

        // Third parameter: specify output tokens from the swap
        params[2] = abi.encode(_key.currency0, _minAmountOut);

        bytes[] memory inputs = new bytes[](1);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap
        router.execute{value: 0}(commands, inputs, _deadline);

        uint256 amountOutEth = address(this).balance;

        uint256 amountOutErc20 = IERC20(Currency.unwrap(_key.currency1))
            .balanceOf(address(this));

        console.log("Amount swaped eth: %s", amountOutEth);
        console.log("Amount left erc20: %s", amountOutErc20);

        // Check we have enough out. Revert if not.
        require(amountOutEth >= _minAmountOut, "Insufficient output amount");

        return amountOutEth;
    }

    /**
     * @dev Approuve permit2 to spend an erc20 token and the Urouter to spend permit2
     */
    function approveTokenWithPermit2(
        address token,
        uint160 amount,
        uint48 expiration
    ) internal {
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(token, address(router), amount, expiration);
    }

    // Receive eth from withdraw
    receive() external payable {}

    /**
     * Withdraw the raffle contract to the owner
     * Security function for testing purposes
     */
    function withdrawContract() external {
        uint256 withdrawAmout = address(this).balance;
        (bool success, ) = payable(owner()).call{value: withdrawAmout}("");
        require(success, "Contract withdraw failed");
    }

    /**
     * Allow withdraw of an erc20 token from the contract
     */
    function withdrawErc20Token(address _token) external {
        IERC20 erc20Token = IERC20(_token);
        if (erc20Token.transfer(owner(), erc20Token.balanceOf(address(this)))) {
            revert WithdrawErc20TokenError("Unable to transfer token:", _token);
        }
    }
}
