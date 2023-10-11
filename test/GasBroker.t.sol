// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import './PermitSigUtils.sol';
import './RewardSigUtils.sol';
import './TestToken.sol';
import "../src/GasBroker.sol";

contract MockPriceOracle is IPriceOracle {
  function getPriceInEth(address token, uint amount) external pure returns (uint256) {
    return 1 ether;
  }
}

contract GasBrokerTest is Test {
  uint256 constant SIGNER_PRIVATE_KEY = 0xA11CE;
  uint256 constant SIGNER_TOKEN_BALANCE = 150e6;
  uint256 constant VALUE = 110e6;
  uint256 constant REWARD = 10e6;

  PermitSigUtils permitSigUtils;
  RewardSigUtils rewardSigUtils;
  GasBroker gasBroker;
  TestToken token;
  IPriceOracle priceOracle;
  address signer;
  uint256 deadline;

  function setUp() public {
    deadline = block.timestamp + 1 days;
    // deploy PriceOracle
    priceOracle = new MockPriceOracle();
    // deploy GasBroker
    gasBroker = new GasBroker(block.chainid, address(priceOracle));
    signer = vm.addr(SIGNER_PRIVATE_KEY);
    // deploy test token
    token = new TestToken();

    // fund wallet with tokens
    token.transfer(signer, SIGNER_TOKEN_BALANCE);
    // burn the rest of tokens
    token.transfer(address(0), token.balanceOf(address(this)));

    // deploy sigUtils
    permitSigUtils = new PermitSigUtils(token.DOMAIN_SEPARATOR());
    rewardSigUtils = new RewardSigUtils(gasBroker.DOMAIN_SEPARATOR());

  }

  function getPermitSignature() internal view returns (uint8 v, bytes32 r, bytes32 s) {
    PermitSigUtils.Permit memory permit = PermitSigUtils.Permit({
      owner: signer,
      spender: address(gasBroker),
      value: VALUE,
      nonce: 0,
      deadline: deadline
    });
    bytes32 digest = permitSigUtils.getTypedDataHash(permit);
    (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
  }

  function getRewardSignature(bytes32 permitHash) internal view returns (uint8 v, bytes32 r, bytes32 s) {
    Reward memory reward = Reward({
      value: REWARD,
      permitHash: permitHash
    });
    bytes32 digest = rewardSigUtils.getTypedDataHash(reward);

    (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
  }

  function test_shouldSwapTokensToETH() public {
    // prepare signature for permit
    (uint8 permitV, bytes32 permitR, bytes32 permitS) = getPermitSignature();

    bytes32 permitHash = keccak256(abi.encode(permitV,permitR,permitS));
    // prepare signature for reward
    (uint8 rewardV, bytes32 rewardR, bytes32 rewardS) = getRewardSignature(permitHash);

    gasBroker.swap{ value: 1 ether }(
      signer,
      address(token),
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

    assertEq(token.balanceOf(address(this)), VALUE);
    assertEq(token.balanceOf(signer), SIGNER_TOKEN_BALANCE - VALUE);
    assertEq(signer.balance, 1 ether);
  }
}
