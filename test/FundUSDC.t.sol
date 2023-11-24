// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import './FundUSDC.sol';
import "solmate/tokens/ERC20.sol";

contract TestFundUSDC is Test {

  FundUSDC fundUSDC;
  ERC20 constant usdc = ERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);
  
  function test_shouldSwapEThtoUSDC() public {
    fundUSDC = new FundUSDC();

    fundUSDC.swapExactOutputSingle{value: 100 ether}(10_000_000, 100 ether);

    assertEq(usdc.balanceOf(address(this)), 10_000_000);
  }
}
