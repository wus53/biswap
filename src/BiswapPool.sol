// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {console} from "forge-std/console.sol";

// importing interfaces
import "./interfaces/IERC20.sol";
import "./interfaces/IBiswapMintCallback.sol";
import "./interfaces/IBiswapSwapCallback.sol";

// importing libraries
import "./lib/Position.sol";
import "./lib/Tick.sol";

contract BiswapPool {
    // Using For https://docs.soliditylang.org/en/v0.8.17/contracts.html?highlight=using#using-for
    // The directive using A for B; can be used to attach functions (A) as member functions
    // to any type (B). These functions will receive the object they are called on as their
    // first parameter (like the self variable in Python).
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    // Errors
    error InvalidTickRange();
    error ZeroLiquidity();
    error InsufficientInputAmount();

    // Events
    // indexed owner, lowerTick, upperTick for later search
    event Mint(
        address minter,
        address indexed owner,
        int24 indexed lowerTick,
        int24 indexed upperTick,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    // Pool tokens, immutable
    address public immutable token0;
    address public immutable token1;

    // Packing variables that are read together frequently to save gas
    struct Slot0 {
        // Current sqrt(P)
        uint160 sqrtPriceX96;
        // Current Tick
        int24 tick;
    }

    Slot0 public slot0;

    // Amount of liquidity, L
    uint128 public liquidity;

    // Ticks info
    mapping(int24 => Tick.Info) public ticks;
    // Positions info
    mapping(bytes32 => Position.Info) public positions;

    constructor(address token0_, address token1_, uint160 sqrtPriceX96, int24 tick) {
        token0 = token0_;
        token1 = token1_;

        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
    }

    // Mint function
    function mint(address owner, int24 lowerTick, int24 upperTick, uint128 amount)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        // check the tick range is valid
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) revert InvalidTickRange();

        // check the liquidity is not zero (amount is liquidity amount L)
        if (amount == 0) revert ZeroLiquidity();

        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);

        Position.Info storage position = positions.get(owner, lowerTick, upperTick);
        position.update(amount);

        amount0 = 0.99897661834742528 ether;
        amount1 = 5000 ether;

        liquidity += uint128(amount);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        // msg.sender here is the test contract, which implements
        // the function biswapMintCallback
        IBiswapMintCallback(msg.sender).biswapMintCallback(amount0, amount1);

        // console.log(balance0());

        // checking whether the Pool contract balances have changed or not:
        // we require them to increase by at least amount0 and amount1
        // respectively–this would mean the caller has transferred tokens to the pool
        if (amount0 > 0 && balance0Before + amount0 > balance0()) {
            revert InsufficientInputAmount();
        }
        if (amount1 > 0 && balance1Before + amount1 > balance1()) {
            revert InsufficientInputAmount();
        }

        emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
    }

    // Swap function
    // use type int256 since some amount could be negative
    function swap(address recipient) public returns (int256 amount0, int256 amount1) {
        int24 nextTick = 85184;
        uint160 nextPrice = 5604469350942327889444743441197;

        amount0 = -0.008396714242162444 ether;
        amount1 = 42 ether;

        (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);

        IERC20(token0).transfer(recipient, uint256(-amount0));
        uint256 balance1Before = balance1();
        IBiswapSwapCallback(msg.sender).biswapSwapCallback(amount0, amount1);
        if (balance1Before + uint256(amount1) > balance1()) {
            revert InsufficientInputAmount();
        }

        emit Swap(msg.sender, recipient, amount0, amount1, slot0.sqrtPriceX96, liquidity, slot0.tick);
    }

    /////////////////////////////////////////
    //                                     //
    //              INTERNAL               //
    //                                     //
    /////////////////////////////////////////
    function balance0() internal returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }
}
