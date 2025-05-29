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

contract SwapERC20ToEthUniSwapV4 is PoolStateReader {
    using StateLibrary for IPoolManager;

    address public linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    UniversalRouter public immutable router;
    // IPoolManager public immutable poolManager;
    IPermit2 public immutable permit2;

    address payable public immutable admin;

    constructor(
        address payable _router,
        address _permit2,
        address _poolManager
    ) PoolStateReader(IPoolManager(_poolManager)) {
        router = UniversalRouter(_router);
        permit2 = IPermit2(_permit2);
        admin = payable(msg.sender);
    }

    function approveTokenWithPermit2(
        address token,
        uint160 amount,
        uint48 expiration
    ) internal {
        IERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(token, address(router), amount, expiration);
    }

    function transferToURouter(uint256 amount, address token) external {
        IERC20(token).transferFrom(msg.sender, address(router), amount);
    }

    function payWithLink(
        bytes calldata _signature,
        address _tokenOwner,
        uint256 _amount,
        uint256 _nonce,
        uint256 _deadline
    ) external {
        // Call the permit2 contract to transfer the tokens in the contract
        permit2.permitTransferFrom(
            ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: linkAddress,
                    amount: _amount
                }),
                nonce: _nonce,
                deadline: _deadline
            }),
            ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: _amount
            }),
            _tokenOwner,
            _signature
        );

        approveTokenWithPermit2(
            linkAddress,
            uint160(_amount),
            uint48(_deadline)
        );

        uint256 amountOut = swapExactInputSingleTokenToEth(
            PoolKey({
                currency0: Currency.wrap(address(0)),
                currency1: Currency.wrap(linkAddress),
                fee: 500,
                tickSpacing: 10,
                hooks: IHooks(address(0))
            }),
            uint128(_amount),
            uint128(0),
            block.timestamp + 1 hours
        );
    }

    function swapExactInputSingleTokenToEth(
        PoolKey memory key, // PoolKey struct that identifies the v4 pool
        uint128 amountIn, // Exact amount of tokens to swap
        uint128 minAmountOut, // Minimum amount of output tokens expected
        uint256 deadline // Timestamp after which the transaction will revert
    ) internal returns (uint256 amountOut) {
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
                poolKey: key,
                zeroForOne: false, // false we want to swap token1 to eth (0x0000000000000000000000000000000000000000) address(Token0) < address(Token1) ALWAYS
                amountIn: amountIn, // amount of tokens we're swapping
                amountOutMinimum: minAmountOut, // minimum amount we expect to receive
                hookData: bytes("") // no hook data needed
            })
        );

        // Second parameter: specify input tokens for the swap
        // encode SETTLE_ALL parameters
        params[1] = abi.encode(key.currency1, amountIn);

        // Third parameter: specify output tokens from the swap
        params[2] = abi.encode(key.currency0, minAmountOut);

        bytes[] memory inputs = new bytes[](1);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap
        router.execute{value: 0}(commands, inputs, deadline);

        amountOut = IERC20(Currency.unwrap(key.currency1)).balanceOf(
            address(this)
        );
        require(amountOut >= minAmountOut, "Insufficient output amount");

        return amountOut;
    }

    // Receive eth from withdraw
    receive() external payable {}

    /**
     * Withdraw the raffle contract to the administrator
     * Security function for testing purposes
     */
    function withdrawContract() external {
        uint256 withdrawAmout = address(this).balance;
        (bool success, ) = admin.call{value: withdrawAmout}("");
        require(success, "Contract withdraw failed");
    }

    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() external {
        IERC20 link = IERC20(linkAddress);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
}
