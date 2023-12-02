// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "solmate/tokens/ERC20.sol";

import './ChainlinkPriceFeed.sol';
import './PermitSigUtils.sol';
import './RewardSigUtils.sol';
import "../src/GasBroker.sol";
import "../src/GasProviderHelper.sol";

contract IntegrationTest is Test {
  using Address for address payable;

  uint256 constant VALUE = 10e6;
  uint256 constant REWARD = 1e6;
  uint256 constant SIGNER_USDC_BALANCE = 15e6;
  uint256 constant SIGNER_PRIVATE_KEY = 0xA11CE;
  ERC20 constant usdc = ERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);//0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  ERC20 constant weth = ERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
  address constant USDC_WHALE = address(0xC882b111A75C0c657fC507C04FbFcD2cC984F071);//0xDa9CE944a37d218c3302F6B82a094844C6ECEb17);

  address signer;
  uint256 deadline;
  IPriceOracle priceOracle;
  ChainlinkPriceFeed chainlinkPriceFeed;
  GasBroker gasBroker;
  PermitSigUtils permitSigUtils;
  RewardSigUtils rewardSigUtils;


  function setUp() public {
    chainlinkPriceFeed = new ChainlinkPriceFeed();
    bytes memory bytecode = abi.encodePacked(vm.getCode("PriceOracle.sol"));
    address deployed;
    assembly {
      deployed := create(0, add(bytecode, 0x20), mload(bytecode))
    }
    priceOracle = IPriceOracle(deployed);

    gasBroker = GasBroker(0x92f1C3d951018C90C364c234ff5fEE00f334072F);//new GasBroker(1, address(priceOracle));

    // deploy sigUtils
    permitSigUtils = new PermitSigUtils(usdc.DOMAIN_SEPARATOR());
    rewardSigUtils = new RewardSigUtils(gasBroker.DOMAIN_SEPARATOR());

    signer = vm.addr(SIGNER_PRIVATE_KEY);
    deadline = block.timestamp + 1 days;

    vm.prank(USDC_WHALE);
    usdc.transfer(signer, SIGNER_USDC_BALANCE);
  }

  function test_shouldSwapTokensToETH() public {
    // prepare signature for permit
    (uint8 permitV, bytes32 permitR, bytes32 permitS) = getPermitSignature(signer, VALUE);

    bytes32 permitHash = keccak256(abi.encodePacked(permitR,permitS,permitV));
    // prepare signature for reward
    (uint8 rewardV, bytes32 rewardR, bytes32 rewardS) = getRewardSignature(REWARD, permitHash);
    uint256 value = gasBroker.getEthAmount(address(usdc), VALUE - REWARD);
    gasBroker.swap{ value: value }(
      signer,
      address(usdc),
      VALUE,
      deadline,
      REWARD,
      permitV,
      permitR,
      permitS,
      rewardV,
      rewardR,
      rewardS
    );

    assertEq(usdc.balanceOf(address(this)), VALUE);
    assertEq(usdc.balanceOf(signer), SIGNER_USDC_BALANCE - VALUE);
    assertEq(signer.balance, value);

    uint256 usdWorth = chainlinkPriceFeed.getEthPriceInUsd() * signer.balance / 10**18;
    console2.log("10 USDC been exchanged with comission of 1 USDC to %s wei worth of %s cents", signer.balance, usdWorth);

  }


  function test_test_shouldSwapUsingFlashLoan() public {
    GasProviderHelper gasProviderHelper = new GasProviderHelper(0x92f1C3d951018C90C364c234ff5fEE00f334072F, address(usdc));

    uint256 value = 10_000 * 10**6;
    uint256 reward = 100 * 10**6;
    vm.prank(USDC_WHALE);
    usdc.transfer(signer, value);

    // prepare signature for permit
    (uint8 permitV, bytes32 permitR, bytes32 permitS) = getPermitSignature(signer, value);

    bytes32 permitHash = keccak256(abi.encodePacked(permitR,permitS,permitV));
    // prepare signature for reward
    (uint8 rewardV, bytes32 rewardR, bytes32 rewardS) = getRewardSignature(reward, permitHash);
    uint256 ethToSend = gasBroker.getEthAmount(address(usdc), value - reward);
    
    bytes memory swapCalldata = abi.encodeWithSignature(
      "swap(address,address,uint256,uint256,uint256,uint8,bytes32,bytes32,uint8,bytes32,bytes32)",
      signer,
      address(usdc),
      value,
      deadline,
      reward,
      permitV,
      permitR,
      permitS,
      rewardV,
      rewardR,
      rewardS
    );

    uint256 balanceBefore = address(this).balance;

    gasProviderHelper.swapWithFlashloan(
      0xA374094527e1673A86dE625aa59517c5dE346d32,
      address(usdc),
      ethToSend,
      swapCalldata
    );

    assertEq(usdc.balanceOf(address(gasProviderHelper)), 0);
    assertEq(weth.balanceOf(address(gasProviderHelper)), 0);
    assertEq(address(gasProviderHelper).balance, 0);

    uint256 usdWorth = chainlinkPriceFeed.getEthPriceInUsd() * signer.balance / 10**18;
    console2.log("10K USDC been exchanged using flashloan with comission of 100 USDC to %s wei worth of %s cents", signer.balance, usdWorth);
    uint256 profitInWei = address(this).balance - balanceBefore;
    uint256 profitInUsd = chainlinkPriceFeed.getEthPriceInUsd() * profitInWei / 10**18;
    console2.log("Gas provider made a profit of %s wei worth of %s cents", profitInWei, profitInUsd);
  }


  function getPermitSignature(address _signer, uint256 _value) internal view returns (uint8 v, bytes32 r, bytes32 s) {
    PermitSigUtils.Permit memory permit = PermitSigUtils.Permit({
      owner: _signer,
      spender: address(gasBroker),
      value: _value,
      nonce: 0,
      deadline: deadline
    });
    bytes32 digest = permitSigUtils.getTypedDataHash(permit);
    (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
  }

  function getRewardSignature(uint256 reward, bytes32 permitHash) internal view returns (uint8 v, bytes32 r, bytes32 s) {
    Reward memory reward = Reward({
      value: reward,
      permitHash: permitHash
    });
    bytes32 digest = rewardSigUtils.getTypedDataHash(reward);

    (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
  }

  receive() external payable {}

}
