// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solmate/tokens/ERC20.sol";

/**
 * @title TestToken
 */
contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TST", 6) {
        _mint(msg.sender, 100_000e6);
    }
}
