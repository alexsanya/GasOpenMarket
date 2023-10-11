// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/GasBroker.sol";

contract RewardSigUtils {
  bytes32 internal DOMAIN_SEPARATOR;

  constructor(bytes32 _DOMAIN_SEPARATOR) {
      DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
  }

  // computes the hash of a reward
  function getStructHash(Reward memory _reward)
      internal
      pure
      returns (bytes32)
  {
      return
          keccak256(
              abi.encode(
                  keccak256("Reward(uint256 value,bytes32 permitHash)"),
                  _reward.value,
                  _reward.permitHash
              )
          );
  }

  // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
  function getTypedDataHash(Reward memory _reward)
      public
      view
      returns (bytes32)
  {
      return
          keccak256(
              abi.encodePacked(
                  "\x19\x01",
                  DOMAIN_SEPARATOR,
                  getStructHash(_reward)
              )
          );
  }
}

