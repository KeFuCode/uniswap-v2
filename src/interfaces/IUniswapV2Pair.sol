// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.10;

interface IUniswapV2Pair {
    function initialize(address token0, address token1) external;
}