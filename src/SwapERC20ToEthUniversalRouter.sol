// // SPDX-License-Identifier: GPL-2.0-or-later
// pragma solidity 0.8.24;
// pragma abicoder v2;

// import '@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol';
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
// /**
//  * !!!!!!ONLY for Sepolia test net!!!!!!!
//  * Using IV3SwapRouter for sepolia as ExactInputSingleParams is different (uint256 deadline)
//  */
// contract SwapERC20ToEth {

//     using SafeERC20 for IERC20;

//     IV3SwapRouter public swapRouter;

//     IERC20 public immutable linkToken;

//     event SwappedLinkToWETH(string message, uint256 amountWETH);
//     event SwappedWETHtoETH(string message, uint256 amountETH);



//     // Sepolia Link
//     address public constant LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
//     // Sepolia WETH uniswap
//     address public constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
//     // Uniswap V3 factory
//     address public constant FACTORY = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;
//     // Pool from getPool on UniswapV3Factory
//     address public constant POOL = 0xA470a353577901AA8cDCb828BB616ef41d58B88a;
//     // SwapRouter02 the one we gonna do the exchange
//     address public constant SWAPROUTERV2 = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
//     // Universal router => ca degage
//     address public constant UROUTER = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;

//     uint24 public feeTier = 10000;
//     uint24 public slippageTolerance = 5000;

//     constructor() {
//         swapRouter = IV3SwapRouter(SWAPROUTERV2);
//         linkToken = IERC20(LINK);
//     }

//     /**
//      * 
//      * @param _amountIn Link in wei
//      * @param _price price in wei
//      */
//     function swapLinkforETH(uint256 _amountIn, uint256 _price) internal returns (uint256 amountOut) {

//         // Approve the router to spend WETH
//         linkToken.forceApprove(SWAPROUTERV2, _amountIn);

//         require(linkToken.allowance(address(this), SWAPROUTERV2) >= _amountIn, "Insufficient approval");
        
//         // Note: To use this example, you should explicitly set slippage limits, omitting for simplicity
//         uint256 minOut = calculateMinAmount(_amountIn, _price);// Impossible cette merde calculateMinAmount(amountIn, price);  /* Calculate min output */
//         uint160 priceLimit = 0;/* Calculate price limit */
//         // Create the params that will be used to execute the swap
//         IV3SwapRouter.ExactInputSingleParams memory params =
//             IV3SwapRouter.ExactInputSingleParams({
//                 tokenIn: LINK,
//                 tokenOut: WETH,
//                 fee: feeTier,
//                 recipient: address(this),
//                 amountIn: _amountIn,
//                 amountOutMinimum: minOut,
//                 sqrtPriceLimitX96: priceLimit
//             });
//         // The call to `exactInputSingle` executes the swap.
//         amountOut = swapRouter.exactInputSingle(params); // Implicit return at the end

//         emit SwappedLinkToWETH('Swapped Link to WETH', amountOut);

//         // Withdraw WETH to eth
//         IWETH weth = IWETH(WETH);
//         uint256 balanceWeth = weth.balanceOf(address(this));
//         weth.withdraw(balanceWeth);

//         emit SwappedWETHtoETH('Swapped WETH to ETH', balanceWeth);
//     }

//     // Receive eth from withdraw
//     receive() external payable {
        
//     }

//     /**
//      * Calculate the amount of expected out token to be received from the swap
//      * Add a 1% of slippage tolerance
//      * @param _amountIn amount to be swapped
//      * @param _price price of the pairs
//      */
//     function calculateMinAmount(uint256 _amountIn, uint256 _price) public view returns(uint256 expecteAmountOut)
//     {
//         uint24 totalFees = feeTier  + slippageTolerance; // Add slippage tolerance
//         uint256 poolFees = _amountIn*totalFees/(10000*100); // poolFeesRate is in % of 10,000
//         expecteAmountOut = (_amountIn - poolFees)*_price/10**18; // Give wei^2 so go back to wei by /10**18
//     }

//     function setSlippageTolerance(uint24 _newSlippageTolerance) public virtual
//     {
//         slippageTolerance = _newSlippageTolerance;
//     }

//     function setFeeTier(uint24 _newFeeTier) public virtual
//     {
//         feeTier = _newFeeTier;
//     }

// }

// /**
//  * Add withdraw interface of WETH to IERC20
//  */
// interface IWETH is IERC20 
// {
//     // Retirer WETH pour obtenir ETH
//     function withdraw(uint256 amount) external;
// }