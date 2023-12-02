// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "solmate/tokens/WETH.sol";

import "forge-std/console2.sol";

contract GasProviderHelper {
  using Address for address payable;

  WETH constant weth = WETH(payable(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270));
  ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
  address immutable gasBroker; //= 0x92f1C3d951018C90C364c234ff5fEE00f334072F;
  //IUniswapV3Pool pool = IUniswapV3Pool(0xA374094527e1673A86dE625aa59517c5dE346d32);
  uint256 constant MAX_INT = 2**256 - 1;


  constructor(address _gasBroker, address token) {
    gasBroker = _gasBroker;
    IERC20(token).approve(address(swapRouter), MAX_INT);
  }

  function swapWithFlashloan(
    address pool,
    address token,
    uint256 weiToBorrow,
    bytes memory swapCalldata
  ) external payable {
    // borrow WMATIC
    bytes memory data = abi.encode(
      msg.sender,
      msg.value,
      token,
      weiToBorrow,
      swapCalldata
    );
    IUniswapV3Pool(pool).flash(address(this), weiToBorrow, 0, data);
  }

  function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
    (
      address gasProvider,
      uint256 extraValue,
      address token,
      uint256 weiToBorrow,
      bytes memory swapCalldata
    ) = abi.decode(
        data,
        (address,uint256,address,uint256,bytes)
    );

    weth.withdraw(weiToBorrow);
    (bool success, bytes memory data) = gasBroker.call{ value: extraValue + weiToBorrow }(swapCalldata);
    require(success, "Swap failed");
    console2.logBytes(data);
    swapExactInputSingle(token, IERC20(token).balanceOf(address(this)));
    weth.deposit{value: address(this).balance}();
    uint256 amountToRepay = weiToBorrow + fee0;
    require(weth.balanceOf(address(this)) >= amountToRepay, "Cannot repay flashloan");

    weth.transfer(msg.sender, amountToRepay);
    uint256 wethBalance = weth.balanceOf(address(this));
    if (wethBalance > 0) {
      weth.withdraw(wethBalance);
      payable(gasProvider).sendValue(wethBalance);
    }
  }

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
