// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import './PermitSigUtils.sol';
import './RewardSigUtils.sol';
import "../src/GasBroker.sol";

contract MockPriceOracle {
  function getPriceInEth(address token, uint amount) external view returns (uint256) {
    return 1 ether;
  }
}

contract GasBrokerTest is Test {
  uint256 constant SIGNER_PRIVATE_KEY = 0xA11CE;
  uint256 constant VALUE = 110e6;
  uint256 constant REWARD = 10e6;

  PermitSigUtils permitSigUtils;
  RewardSigUtils RewardSigUtils;
  GasBroker gasBroker;
  TestToken token;
  IPriceOracle priceOracle;
  address signer;

  function setUp() public {
    // deploy PriceOracle
    priceOracle = new MockPriceOracle();
    // deploy GasBroker
    gasBroker = new GasBroker(1, address(priceOracle));
    signer = vm.addr(SIGNER_PRIVATE_KEY);
    // deploy test token
    token = new TestToken();

    // fund wallet with tokens
    token.transfer(signer, 150e6);

    // deploy sigUtils
    permitSigUtils = new PermitSigUtils(token.DOMAIN_SEPARATOR());
    rewardSigUtils = new RewardSigUtils(gasBroker.DOMAIN_SEPARATOR());

  }

  function test_shouldSwapTokensToETH() public {
    uint256 deadline = block.timestamp + 1 days;
    // prepare signature for permit
    permitSigUtils.Permit memory permit = permitSigUtils.Permit({
        owner: signer,
        spender: address(gasBroker),
        value: VALUE,
        nonce: 0,
        deadline: deadline
    });
    bytes32 digest = permitSigUtils.getTypedDataHash(permit);
    (uint8 permitV, bytes32 permitR, bytes32 permitS) = vm.sign(SIGNER_PRIVATE_KEY, digest);
    bytes32 permitHash = keccak256(abi.encode(permitV,permitR,permitS));
    // prepare signature for reward
    Reward memory reward = Reward({
      value: REWARD,
      permitHash: permitHash
    });
    digest = rewardSigUtils.getRewardTypedDataHash(reward);
    (uint8 rewardV, bytes32 rewardR, bytes32 rewardS) = vm.sign(SIGNER_PRIVATE_KEY, digest);

    uint256 gasProviderTokenBalanceBefore = token.balanceOf(address(this));
    uint256 signerTokenBalanceBefore = token.balanceOf(signer);
    uint256 signerBalanceBefore = signer.balance;
    gasBroker.swap{ value: 1 ether }(
      signer,
      address(token),
      VALUE,
      deadline,
      permitV,
      permitR,
      permitS,
      rewardV,
      rewardR,
      rewardS
    );

    assertEq(token.balanceOf(address(this)), gasProviderTokenBalanceBefore + VALUE);
    assertEq(token.balanceOf(signer), signerTokenBalanceBefore - VALUE);
    assertEq(signer.balance, signerBalanceBefore + 1 ether);
  }
}
