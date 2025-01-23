// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LiquidityPool is ERC20 {
    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public constant FEE_RATE = 30; // 0.3% fee (30 basis points)

    constructor(address _tokenA, address _tokenB)
        ERC20("Liquidity Provider Token", "LPT")
    {
        tokenA = IERC20(_tokenA); // Initialize Token A
        tokenB = IERC20(_tokenB); // Initialize Token B
    }

    modifier ensure(uint256 deadline) {
        require(block.timestamp <= deadline, "Transaction expired");
        _;
    }

    // Add Liquidity
    function addLiquidity(uint256 amountA, uint256 amountB)
        external
        returns (uint256 lpTokens)
    {
        require(
            amountA > 0 && amountB > 0,
            "Amounts must be greater than zero"
        );

        // Ensure user has sufficient token balances
        require(
            tokenA.balanceOf(msg.sender) >= amountA,
            "Insufficient balance for Token A"
        );
        require(
            tokenB.balanceOf(msg.sender) >= amountB,
            "Insufficient balance for Token B"
        );

        if (reserveA == 0 && reserveB == 0) {
            // First liquidity addition: initialize pool
            lpTokens = sqrt(amountA * amountB);
        } else {
            // Check if token ratios match
            require(
                (reserveA * amountB) == (reserveB * amountA),
                "Token ratio mismatch"
            );

            // Calculate LP tokens to mint based on existing liquidity
            lpTokens = (totalSupply() * amountA) / reserveA;
        }

        // Transfer tokens from user to the contract
        require(
            tokenA.transferFrom(msg.sender, address(this), amountA),
            "Token A transfer failed"
        );
        require(
            tokenB.transferFrom(msg.sender, address(this), amountB),
            "Token B transfer failed"
        );

        // Update reserves
        reserveA += amountA;
        reserveB += amountB;

        // Mint LP tokens to the user
        _mint(msg.sender, lpTokens);
    }

    //Remove liquidity
    function removeLiquidity(uint256 lpTokens)
        external
        returns (uint256 amountA, uint256 amountB)
    {
        require(lpTokens > 0, "Percentage should be greater than 0");
        uint256 totalSupply = totalSupply();
        amountA = (reserveA * lpTokens) / totalSupply;
        amountB = (reserveB * lpTokens) / totalSupply;
        _burn(msg.sender, lpTokens);
        reserveA -= amountA;
        reserveB -= amountB;
        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);
    }

    //Swap
    function swap(
        uint256 amountIn,
        address tokenIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountOut) {
        require(amountIn > 0, "Incorrect Amount");
        require(
            tokenIn == address(tokenA) || tokenIn == address(tokenB),
            "Unsupported token"
        );
        bool isAtoB = tokenIn == address(tokenA);
        (uint256 reserveIn, uint256 reserveOut) = isAtoB
            ? (reserveA, reserveB)
            : (reserveB, reserveA);
        uint256 amountInWithFee = (amountIn * (10000 - FEE_RATE)) / 10000;
        amountOut =
            (reserveOut * amountInWithFee) /
            (reserveIn + amountInWithFee);
        require(amountOut >= minAmountOut, "Slippage exceeded");
        if (isAtoB) {
            reserveA += amountIn;
            reserveB -= amountOut;
            tokenA.transferFrom(msg.sender, address(this), amountIn);
            tokenB.transfer(msg.sender, amountOut);
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
            tokenB.transferFrom(msg.sender, address(this), amountIn);
            tokenA.transfer(msg.sender, amountOut);
        }
    }

    // Utility function: Square root
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
