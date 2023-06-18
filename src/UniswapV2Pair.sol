// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "solmate/tokens/ERC20.sol";
import "./libraries/Math.sol";

interface IERC20 {
    function balanceOf(address) external returns (uint256);
}

contract UniswapV2Pair is ERC20, Math {
    address public token0;
    address public token1;

    uint256 private reserve0;
    uint256 private reserve1;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    constructor(
        address _token0,
        address _token1
    ) ERC20("UniswapV2 Pair", "UNIV2", 18) {
        token0 = _token0;
        token1 = _token1;
    }

    error InsufficientLiquidityMinted();

    function mint() public {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;

        uint256 liquidity;

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1);
        } else {
            liquidity = Math.min(
                (amount0 * totalSupply) / reserve0,
                (amount1 * totalSupply) / reserve1
            );
        }

        if (liquidity <= 0) revert InsufficientLiquidityMinted();

        _mint(msg.sender, liquidity);

        // _update(balance0, balance1);

        emit Mint(msg.sender, amount0, amount1);
    }
}