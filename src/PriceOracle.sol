// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract PriceOracle {
    uint32 public constant TWAP_PERIOD = 180;
    address public constant WETH = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;//0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IUniswapV3Factory immutable factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function getPriceInEth(address token, uint amount) external view returns (uint256) {
        return getOracleQuote(token, _toUint128(amount), TWAP_PERIOD);
    }

    function getOracleQuote(address token, uint128 amount, uint32 twapPeriod) private view returns (uint256) {
        address uniswapV3Pool = getPool(token);

        (int24 arithmeticMeanTick,) = OracleLibrary.consult(uniswapV3Pool, twapPeriod);
        return OracleLibrary.getQuoteAtTick(
            arithmeticMeanTick,
            amount, 
            token,
            WETH
        );
    }

    function _toUint128(uint256 amount) private pure returns (uint128 n) {
        require(amount == (n = uint128(amount)));
    }

    function getPool(address token) private view returns (address) {
        address pool = factory.getPool(token, WETH, 500);
        if (pool != address(0)) {
            return pool;
        }
        pool = factory.getPool(token, WETH, 1000);
        if (pool != address(0)) {
            return pool;
        }
        pool = factory.getPool(token, WETH, 10000);
        if (pool != address(0)) {
            return pool;
        }
        revert("Pool is not found in Uniswap V3");
    }
}
