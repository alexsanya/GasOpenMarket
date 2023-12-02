// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import '../src/GasProviderHelper.sol';
import './FundUSDC.sol';
import "solmate/tokens/ERC20.sol";

contract TestGasProviderHelper is Test {

  GasProviderHelper gasProviderHelper;
  ERC20 constant usdc = ERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);
  uint256 constant MAX_INT = 2**256 - 1;
  
  function test_shouldSwapUSDCforETH() public {
    FundUSDC fundUSDC = new FundUSDC();
    gasProviderHelper = new GasProviderHelper();
    fundUSDC.swapExactOutputSingle{value: 100 ether}(10_000_000, 100 ether);
    assertEq(usdc.balanceOf(address(this)), 10_000_000);
    usdc.approve(address(gasProviderHelper), MAX_INT);
    uint256 balanceBefore = address(this).balance;
    gasProviderHelper.swapTokensForGas(address(usdc));
    
    assertEq(usdc.balanceOf(address(this)), 0);
    console2.log("10 USDC been exchanged for %s MATIC", address(this).balance - balanceBefore);

  }

  receive() external payable {}
}
