// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IPriceOracle {
  function getPriceInEth(address token, uint amount) external view returns (uint256);
}

interface IERC2612 {
  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}

struct Reward {
  uint256 value;
  bytes32 permitHash; //keccak256 for permit signature
}

contract GasBroker {
  using Address for address payable;

  uint32 constant TWAP_PERIOD = 180;
  bytes32 public immutable DOMAIN_SEPARATOR;
  IPriceOracle immutable priceOracle;

  constructor(uint256 chainId, address _priceOracle) {
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes("Gas broker")),
        keccak256("1"),
        chainId,
        address(this)
      )
    );
    priceOracle = IPriceOracle(_priceOracle);
  }

  function swap(
    address signer,
    address token,
    uint256 value,
    uint256 deadline,
    uint256 reward,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS,
    uint8 rewardV,
    bytes32 rewardR,
    bytes32 rewardS) external payable {
      require(value > reward, "Reward could not exceed value");

      bytes32 permitHash = keccak256(abi.encode(permitV,permitR,permitS));
      require(
        verifyReward(
          signer,
          Reward({
            value: reward,
            permitHash: permitHash
          }),
          rewardV,
          rewardR,
          rewardS
        ),
        "Reward signature is invalid"
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
      uint256 ethAmount = _getEthAmount(token, value - reward);
      require(msg.value >= ethAmount, "Not enough ETH provided");
      payable(signer).sendValue(ethAmount);
      SafeERC20.safeTransfer(IERC20(token), msg.sender, value);
    }

    function hashReward(Reward memory reward) private view returns (bytes32) {
      return keccak256(
        abi.encodePacked(
          "\x19\x01",
          DOMAIN_SEPARATOR,
          keccak256(
            abi.encode(
              keccak256("Reward(uint256 value,bytes32 permitHash)"),
              reward.value,
              reward.permitHash
            )
          )
        )
      );
    }

    function verifyReward(
      address signer,
      Reward memory reward,
      uint8 sigV,
      bytes32 sigR,
      bytes32 sigS
    ) private view returns (bool) {
      return signer == ecrecover(hashReward(reward), sigV, sigR, sigS);
    }

    function _getEthAmount(address token, uint256 amount) internal view returns (uint256 ethAmount) {
      ethAmount = priceOracle.getPriceInEth(address(token), amount);
    }
    
    function getEthAmount(address token, uint256 amount) external view returns (uint256 ethAmount) {
      ethAmount = _getEthAmount(token, amount);
    }

}
