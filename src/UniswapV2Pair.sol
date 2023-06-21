// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "solmate/tokens/ERC20.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";
import "./interfaces/IUniswapV2Callee.sol";

interface IERC20 {
    function balanceOf(address) external returns (uint256);
}

error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();
error TransferFailed();
error InsufficientOutputAmount();
error InsufficientLiquidity();
error InvalidK();
error BalanceOverflow();
error AlreadyInitialized();
error InsufficientInputAmount();

contract UniswapV2Pair is ERC20, Math {
    using UQ112x112 for uint224;

    uint256 constant MINIMUM_LIQUIDITY = 1_000;

    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    bool private isEntered;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(address indexed sender, uint256 amount0Out, uint256 amount1Out, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

    modifier nonReentrant() {
        require(!isEntered);
        isEntered = true;

        _;

        isEntered = false;
    }

    constructor() ERC20("UniswapV2 Pair", "UNIV2", 18) {}

    function initialize(address token0_, address token1_) public {
        if (token0_ != address(0) || token1_ != address(0)) {
            revert AlreadyInitialized();
        }

        token0 = token0_;
        token1 = token1_;
    }

    function mint(address to) public {
        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - reserve0_;
        uint256 amount1 = balance1 - reserve1_;

        uint256 liquidity;

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(
                (amount0 * totalSupply) / reserve0,
                (amount1 * totalSupply) / reserve1
            );
        }

        if (liquidity <= 0) revert InsufficientLiquidityMinted();

        _mint(to, liquidity);

        _update(balance0, balance1, reserve0_, reserve1_);

        emit Mint(to, amount0, amount1);
    }

    function burn(address to) public returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        amount0 = (liquidity * balance0) / totalSupply;
        amount1 = (liquidity * balance1) / totalSupply;

        if (amount0 <= 0 || amount1 <= 0) revert InsufficientLiquidityBurned();

        _burn(address(this), liquidity);

        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
        _update(balance0, balance1, reserve0_, reserve1_);

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) public nonReentrant() {
        if (amount0Out == 0 && amount1Out == 0) revert InsufficientOutputAmount();
    
        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();

        if (amount0Out > reserve0_ || amount1Out > reserve1_) revert InsufficientLiquidity();

        if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));        

        uint256 amount0In = balance0 > reserve0_ - amount0Out ? balance0 - (reserve0_ - amount0Out) : 0;
        uint256 amount1In = balance1 > reserve1_ - amount1Out ? balance1 - (reserve1_ - amount1Out) : 0;

        if (amount0In == 0 && amount1In == 0) revert InsufficientInputAmount();

        uint256 balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
        uint256 balance1Adjusted = (balance1 * 1000) - (amount1In * 3);

        if (balance0Adjusted * balance1Adjusted < uint256(reserve0_) * uint256(reserve1_) * 1000**2) revert InvalidK();
    
        _update(balance0, balance1, reserve0_, reserve1_);

        emit Swap(msg.sender, amount0Out, amount1Out, to);
    }

    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, 0);
    }

    function _update(uint256 balance0, uint256 balance1, uint112 reserve0_, uint112 reserve1_) private {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert BalanceOverflow();

        unchecked {
            uint32 timeElapsed = uint32(block.timestamp) - blockTimestampLast;

            if (timeElapsed > 0 && reserve0_ > 0 && reserve1_ > 0) {
                price0CumulativeLast += uint256(UQ112x112.encode(reserve1_).uqdiv(reserve0_)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(reserve0_).uqdiv(reserve1_)) * timeElapsed;
            }
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp);

        emit Sync(reserve0, reserve1);
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
        // require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }
}
