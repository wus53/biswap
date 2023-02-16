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
import "./lib/TickBitmap.sol";
import "./lib/Math.sol";
import "./lib/TickMath.sol";
import "./lib/SwapMath.sol";

contract BiswapPool {
    // Using For https://docs.soliditylang.org/en/v0.8.17/contracts.html?highlight=using#using-for
    // The directive using A for B; can be used to attach functions (A) as member functions
    // to any type (B). These functions will receive the object they are called on as their
    // first parameter (like the self variable in Python).
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
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

    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    // Pool contract needs to find all liquidity that’s required to
    // “fill an order” from user. This is done via iterating over
    // initialized ticks in a direction chosen by user.
    /// @notice sqrtPriceX96 and tick are new current price and tick after a swap is done.
    /// SwapState maintains current swap’s state.
    struct SwapState {
        uint256 amountSpecifiedRemaining;
        uint256 amountCalculated;
        uint160 sqrtPriceX96;
        int24 tick;
    }

    /// @notice StepState maintains current swap step’s state. This
    /// structure tracks the state of one iteration of an “order filling”
    /// @notice After we implement cross-tick swaps (that is, swaps that
    /// happen across multiple price ranges), the idea of iterating will be clearer.
    struct StepState {
        uint160 sqrtPriceStartX96;
        int24 nextTick;
        uint160 sqrtPriceNextX96;
        uint256 amountIn;
        uint256 amountOut;
    }

    Slot0 public slot0;

    // Amount of liquidity, L
    uint128 public liquidity;

    // Ticks info
    mapping(int24 => Tick.Info) public ticks;
    // TickBitmap
    mapping(int16 => uint256) public tickBitmap;
    // Positions info
    mapping(bytes32 => Position.Info) public positions;

    constructor(
        address token0_,
        address token1_,
        uint160 sqrtPriceX96,
        int24 tick
    ) {
        token0 = token0_;
        token1 = token1_;

        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
    }

    // Mint function
    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1) {
        // check the tick range is valid
        if (
            lowerTick >= upperTick ||
            lowerTick < MIN_TICK ||
            upperTick > MAX_TICK
        ) revert InvalidTickRange();

        // check the liquidity is not zero (amount is liquidity amount L)
        if (amount == 0) revert ZeroLiquidity();

        bool flippedLower = ticks.update(lowerTick, amount);
        bool flippedUpper = ticks.update(upperTick, amount);

        if (flippedLower) {
            tickBitmap.flipTick(lowerTick, 1);
        }

        if (flippedUpper) {
            tickBitmap.flipTick(upperTick, 1);
        }

        Position.Info storage position = positions.get(
            owner,
            lowerTick,
            upperTick
        );
        position.update(amount);

        // amount0 = 0.99897661834742528 ether;
        // amount1 = 5000 ether;
        Slot0 memory slot0_ = slot0;

        // calcAmount0Delta(uint160 sqrtPriceAX96, uint160 sqrtPriceBX96, uint128 liquidity)
        // we should use getSqrtRatioAtTick(slot0_.tick) to get current price instead of
        // using slot_.sqrtPriceX96 directly to avoid arithmetic overflow/underflow
        amount0 = Math.calcAmount0Delta(
            TickMath.getSqrtRatioAtTick(slot0_.tick),
            TickMath.getSqrtRatioAtTick(upperTick),
            amount
        );

        amount1 = Math.calcAmount1Delta(
            TickMath.getSqrtRatioAtTick(slot0_.tick),
            TickMath.getSqrtRatioAtTick(lowerTick),
            amount
        );

        liquidity += uint128(amount);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        // msg.sender here is the test contract, which implements
        // the function biswapMintCallback
        IBiswapMintCallback(msg.sender).biswapMintCallback(
            amount0,
            amount1,
            data
        );

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

        emit Mint(
            msg.sender,
            owner,
            lowerTick,
            upperTick,
            amount,
            amount0,
            amount1
        );
    }

    // Swap function
    // use type int256 since some amount could be negative
    // zeroForOne is the flag that controls swap direction: when true,
    // token0 is traded in for token1; when false, it’s the opposite.
    // For example, if token0 is ETH and token1 is USDC,
    // setting zeroForOne to true means buying USDC for ETH. amountSpecified
    // is the amount of tokens user wants to sell.
    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        // int24 nextTick = 85184;
        // uint160 nextPrice = 5604469350942327889444743441197;

        // amount0 = -0.008396714242162444 ether;
        // amount1 = 42 ether;
        Slot0 memory slot0_ = slot0;

        // initial state
        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0_.sqrtPriceX96,
            tick: slot0_.tick
        });

        while (state.amountSpecifiedRemaining > 0) {
            StepState memory step;
            step.sqrtPriceStartX96 = state.sqrtPriceX96;
            (step.nextTick, ) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                1,
                zeroForOne
            );
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

            // state.sqrtPriceX96 is the current price that will be set after the swap
            (state.sqrtPriceX96, step.amountIn, step.amountOut) = SwapMath
                .computeSwapStep(
                    state.sqrtPriceX96,
                    step.sqrtPriceNextX96,
                    liquidity,
                    state.amountSpecifiedRemaining
                );

            state.amountSpecifiedRemaining -= step.amountIn;
            state.amountCalculated += step.amountOut;
            state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
        }

        if (state.tick != slot0_.tick) {
            (slot0.sqrtPriceX96, slot0.tick) = (state.sqrtPriceX96, state.tick);
        }

        // zeroForOne == true, SELLING token0 for token1 => amount1 is negative
        // amountSpecified - amountSpecifiedRemaining => actual available amount to be swapped
        (amount0, amount1) = zeroForOne
            ? (
                int256(amountSpecified - state.amountSpecifiedRemaining),
                -int256(state.amountCalculated)
            )
            : (
                -int256(state.amountCalculated),
                int256(amountSpecified - state.amountSpecifiedRemaining)
            );

        if (zeroForOne) {
            IERC20(token1).transfer(recipient, uint256(-amount1));

            uint256 balance0Before = balance0();
            IBiswapSwapCallback(msg.sender).biswapSwapCallback(
                amount0,
                amount1,
                data
            );
            if (balance0Before + uint256(amount0) > balance0())
                revert InsufficientInputAmount();
        } else {
            IERC20(token0).transfer(recipient, uint256(-amount0));

            uint256 balance1Before = balance1();
            IBiswapSwapCallback(msg.sender).biswapSwapCallback(
                amount0,
                amount1,
                data
            );
            if (balance1Before + uint256(amount1) > balance1())
                revert InsufficientInputAmount();
        }

        emit Swap(
            msg.sender,
            recipient,
            amount0,
            amount1,
            slot0.sqrtPriceX96,
            liquidity,
            slot0.tick
        );
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
