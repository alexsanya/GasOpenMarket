pragma solidity ^0.8.0;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "solmate/tokens/WETH.sol";

contract FundUSDC {
  address constant USDC = address(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);
  WETH constant weth = WETH(payable(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270));

  ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

  function swapExactOutputSingle(uint256 amountOut, uint256 amountInMaximum) external payable returns (uint256 amountIn) {
        weth.deposit{ value: msg.value }();
        TransferHelper.safeApprove(address(weth), address(swapRouter), amountInMaximum);

        ISwapRouter.ExactOutputSingleParams memory params =
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(weth),
                tokenOut: USDC,
                fee: 500,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
        amountIn = swapRouter.exactOutputSingle(params);

        // For exact output swaps, the amountInMaximum may not have all been spent.
        // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund the msg.sender and approve the swapRouter to spend 0.
        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(address(weth), address(swapRouter), 0);
            TransferHelper.safeTransfer(address(weth), msg.sender, amountInMaximum - amountIn);
        }
    }
}
