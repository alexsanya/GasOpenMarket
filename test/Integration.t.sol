// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "solmate/tokens/ERC20.sol";

import './ChainlinkPriceFeed.sol';
import './PermitSigUtils.sol';
import './RewardSigUtils.sol';
import "../src/GasBroker.sol";

contract IntegrationTest is Test {
  using Address for address payable;

  uint256 constant VALUE = 100e6;
  uint256 constant REWARD = 10e6;
  uint256 constant SIGNER_USDC_BALANCE = 150e6;
  uint256 constant SIGNER_PRIVATE_KEY = 0xA11CE;
  ERC20 constant usdc = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  address constant USDC_WHALE = address(0xDa9CE944a37d218c3302F6B82a094844C6ECEb17);

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

    gasBroker = new GasBroker(1, address(priceOracle));

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

    bytes32 permitHash = keccak256(abi.encode(permitV,permitR,permitS));
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
    console2.log("100 USDC been exchanged with comission of 10 USDC to %s wei worth of %s cents", signer.balance, usdWorth);

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


}
