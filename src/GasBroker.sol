// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "solmate/tokens/ERC20.sol";

interface IERC2612 {
  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}

struct Asquisition {
  uint256 value;
  bytes32 permitHash; //keccak256 for permit signature
}

contract GasBroker {
  event Swap(bytes32 permitHash);

  using Address for address payable;

  string public constant name = "Gas broker";
  string public constant version = "1";

  bytes32 public immutable DOMAIN_SEPARATOR;

  constructor(uint256 chainId) {
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes(name)),
        keccak256(bytes(version)),
        chainId,
        address(this)
      )
    );
  }

  function swap(
    address signer,
    address token,
    uint256 value,
    uint256 deadline,
    uint256 asquisition,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS,
    uint8 asqV,
    bytes32 asqR,
    bytes32 asqS) external payable {
      bytes32 permitHash = keccak256(abi.encodePacked(permitR,permitS,permitV));
      require(
        verifyAsquisition(
          signer,
          asquisition,
          permitHash,
          asqV,
          asqR,
          asqS
        ),
        "Asquisition signature is invalid"
      );
      IERC2612(token).permit(
        signer,
        address(this),
        value,
        deadline,
        permitV,
        permitR,
        permitS
      );
      SafeERC20.safeTransferFrom(IERC20(token), signer, address(this), value);
      require(msg.value >= asquisition, "Not enough ETH provided");
      payable(signer).sendValue(asquisition);
      if (msg.value > asquisition) {
        payable(msg.sender).sendValue(msg.value - asquisition);
      }
      SafeERC20.safeTransfer(IERC20(token), msg.sender, value);
      emit Swap(permitHash);
    }

    function hashAsquisition(Asquisition memory asquisition) private view returns (bytes32) {
      return keccak256(
        abi.encodePacked(
          "\x19\x01",
          DOMAIN_SEPARATOR,
          keccak256(
            abi.encode(
              keccak256("Asquisition(uint256 value,bytes32 permitHash)"),
              asquisition.value,
              asquisition.permitHash
            )
          )
        )
      );
    }

    function verifyAsquisition(
      address signer,
      uint256 value,
      bytes32 permitHash,
      uint8 sigV,
      bytes32 sigR,
      bytes32 sigS
    ) private view returns (bool) {
      return signer == ecrecover(hashAsquisition(Asquisition(value, permitHash)), sigV, sigR, sigS);
    }
}
