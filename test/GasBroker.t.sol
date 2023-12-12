// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import './PermitSigUtils.sol';
import './RewardSigUtils.sol';
import './TestToken.sol';
import "../src/GasBroker.sol";

contract GasBrokerTest is Test {
  uint256 constant SIGNER_PRIVATE_KEY = 0xA11CE;
  uint256 constant SIGNER_TOKEN_BALANCE = 150e6;
  uint256 constant VALUE = 110e6;
  uint256 constant ASQUISITION = 130e18;

  PermitSigUtils permitSigUtils;
  RewardSigUtils rewardSigUtils;
  GasBroker gasBroker;
  TestToken token;
  address signer;
  uint256 deadline;

  uint8 permitV;
  bytes32 permitR;
  bytes32 permitS;
  uint8 asqV;
  bytes32 asqR;
  bytes32 asqS;

  bytes32 permitHash;

  function setUp() public {
    deadline = block.timestamp + 1 days;
    // deploy GasBroker
    gasBroker = new GasBroker(block.chainid);
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

    // prepare signature for permit
    (permitV, permitR, permitS) = getPermitSignature(signer, VALUE);

    permitHash = keccak256(abi.encodePacked(permitR,permitS,permitV));
    // prepare signature for reward
    (asqV, asqR, asqS) = getRewardSignature(ASQUISITION, permitHash);
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

  function getRewardSignature(uint256 asquisition, bytes32 permitHash) internal view returns (uint8 v, bytes32 r, bytes32 s) {
    Asquisition memory asquisition = Asquisition({
      value: asquisition,
      permitHash: permitHash
    });
    bytes32 digest = rewardSigUtils.getTypedDataHash(asquisition);

    (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
  }

  function test_shouldRevertWhenPermitHashInAsquisitionMessageIsInvalid() public {
    // prepare signature for permit
    (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(signer, VALUE + 1);


    bytes32 permitHash = keccak256(abi.encode(v,r,s));
    // prepare signature for asquisition
    (uint8 asqV, bytes32 asqR, bytes32 asqS) = getRewardSignature(ASQUISITION, permitHash);
    vm.expectRevert("Asquisition signature is invalid");
    gasBroker.swap{ value: ASQUISITION }(
      signer,
      address(token),
      VALUE,
      deadline,
      ASQUISITION,
      permitV,
      permitR,
      permitS,
      asqV,
      asqR,
      asqS
    );
  }

  function test_shouldRevertWhenSignerInAsquisitionMessageIsInvalid() public {
    // prepare signature for reward
    Asquisition memory asquisition = Asquisition({
      value: ASQUISITION,
      permitHash: permitHash
    });
    bytes32 digest = rewardSigUtils.getTypedDataHash(asquisition);

    (uint8 asqV, bytes32 asqR, bytes32 asqS) = vm.sign(0xB22DF, digest);
    vm.expectRevert("Asquisition signature is invalid");
    gasBroker.swap{ value: ASQUISITION }(
      signer,
      address(token),
      VALUE,
      deadline,
      ASQUISITION,
      permitV,
      permitR,
      permitS,
      asqV,
      asqR,
      asqS
    );
  }


  function test_shouldRevertWhenValueInAsquisitionMessageIsInvalid() public {
    (uint8 asqV, bytes32 asqR, bytes32 asqS) = getRewardSignature(ASQUISITION + 1, permitHash);
    vm.expectRevert("Asquisition signature is invalid");
    gasBroker.swap{ value: ASQUISITION }(
      signer,
      address(token),
      VALUE,
      deadline,
      ASQUISITION,
      permitV,
      permitR,
      permitS,
      asqV,
      asqR,
      asqS
    );
  }

  function test_shouldRevertWhenNotEnouthETHisProvided() public {
    vm.expectRevert("Not enough ETH provided");
    gasBroker.swap{ value: ASQUISITION - 1 }(
      signer,
      address(token),
      VALUE,
      deadline,
      ASQUISITION,
      permitV,
      permitR,
      permitS,
      asqV,
      asqR,
      asqS
    );
  }


  function test_shouldSwapTokensToETH() public {
    gasBroker.swap{ value: ASQUISITION }(
      signer,
      address(token),
      VALUE,
      deadline,
      ASQUISITION,
      permitV,
      permitR,
      permitS,
      asqV,
      asqR,
      asqS
    );

    assertEq(token.balanceOf(address(this)), VALUE);
    assertEq(token.balanceOf(signer), SIGNER_TOKEN_BALANCE - VALUE);
    assertEq(signer.balance, ASQUISITION);
  }
}
