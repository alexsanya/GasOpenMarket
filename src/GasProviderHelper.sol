// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "solmate/tokens/WETH.sol";

contract GasProviderHelper {
  using Address for address payable;

  WETH constant weth = WETH(payable(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270));
  ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

  function swapTokensForGas(address token) external {
    uint256 tokenBalance = IERC20(token).balanceOf(msg.sender);
    SafeERC20.safeTransferFrom(IERC20(token), msg.sender, address(this), tokenBalance);
    IERC20(token).approve(address(swapRouter), tokenBalance);
    uint256 wethBalance = swapExactInputSingle(token, tokenBalance);
    weth.withdraw(wethBalance);
    payable(msg.sender).sendValue(wethBalance);
  }

  function swapExactInputSingle(address tokenIn, uint256 amountIn) private returns (uint256 amountOut) {
    ISwapRouter.ExactInputSingleParams memory params =
        ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: address(weth),
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

    amountOut = swapRouter.exactInputSingle(params);
  }

  receive() external payable {}

}
