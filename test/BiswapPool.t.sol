//SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "./TestUtils.sol";
import "../src/BiswapPool.sol";
import "./ERC20Mintable.sol";

contract BiswapPoolTest is Test, TestUtils {
    ERC20Mintable token0;
    ERC20Mintable token1;
    BiswapPool pool;

    bool transferInMintCallback = true;
    bool transferInSwapCallback = true;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool transferInMintCallback;
        bool transferInSwapCallback;
        bool mintLiquidity;
    }

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    function testMintSuccess() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            transferInMintCallback: true,
            transferInSwapCallback: false,
            mintLiquidity: true
        });

        // We expect specific pre-calculated amounts. And we can also check
        // that these amounts were actually transferred to the pool
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

        uint256 expectedAmount0 = 0.99897661834742528 ether;
        uint256 expectedAmount1 = 5000 ether;

        assertEq(poolBalance0, expectedAmount0, "incorrect token0 deposited amount");

        assertEq(poolBalance1, expectedAmount1, "incorrect token0 deposited amount");

        assertEq(token0.balanceOf(address(pool)), expectedAmount0);
        assertEq(token1.balanceOf(address(pool)), expectedAmount1);

        // we need to check the position the pool created for us
        bytes32 positionKey = keccak256(abi.encodePacked(address(this), params.lowerTick, params.upperTick));
        uint128 posLiquidity = pool.positions(positionKey);
        assertEq(posLiquidity, params.liquidity);

        // we need to check the ticks the pool created for us
        (bool tickInitialized, uint128 tickLiquidity) = pool.ticks(params.lowerTick);
        assertTrue(tickInitialized);
        assertEq(tickLiquidity, params.liquidity);

        (tickInitialized, tickLiquidity) = pool.ticks(params.upperTick);
        assertTrue(tickInitialized);
        assertEq(tickLiquidity, params.liquidity);

        // finally, check sqrtP and L
        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(sqrtPriceX96, 5602277097478614198912276234240, "invalid current sqrtP");
        assertEq(tick, 85176, "invalid current tick");
        assertEq(pool.liquidity(), 1517882343751509868544, "invalid current liquidity");
    }

    function testSwapBuyEth() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            transferInMintCallback: false,
            transferInSwapCallback: true,
            mintLiquidity: true
        });

        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);
        int256 userBalanceBefore = int256(token0.balanceOf(address(this)));

        uint256 swapAmount = 42 ether;
        token1.mint(address(this), swapAmount);
        token1.approve(address(this), swapAmount);

        BiswapPool.CallbackData memory extra =
            BiswapPool.CallbackData({token0: address(token0), token1: address(token1), payer: address(this)});

        // The function returns token amounts used in the swap, and we can
        // check them right away:
        (int256 amount0Delta, int256 amount1Delta) = pool.swap(address(this), abi.encode(extra));

        assertEq(amount0Delta, -0.008396714242162444 ether, "invalid ETH out");
        assertEq(amount1Delta, 42 ether, "invalid USDC in");

        // Then, we need to ensure that tokens were actually transferred from the caller:
        assertEq(token0.balanceOf(address(this)), uint256(userBalanceBefore - amount0Delta), "invalid user ETH balance");
        assertEq(token1.balanceOf(address(this)), 0, "invalid user USDC balance");

        // And sent to the pool contract:
        assertEq(
            token0.balanceOf(address(pool)), uint256(int256(poolBalance0) + amount0Delta), "invalid pool ETH balance"
        );
        assertEq(
            token1.balanceOf(address(pool)), uint256(int256(poolBalance1) + amount1Delta), "invalid pool USDC balance"
        );

        // Finally, we’re checking that the pool state was updated correctly:
        // Notice that swapping doesn’t change the current liquidity–in a
        // later chapter, we’ll see when it does change it.
        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(sqrtPriceX96, 5604469350942327889444743441197, "invalid current sqrtP");
        assertEq(tick, 85184, "invalid current tick");
        assertEq(pool.liquidity(), 1517882343751509868544, "invalid current liquidity");
    }

    function testSwapInsufficientInputAmount() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            transferInMintCallback: false,
            transferInSwapCallback: false,
            mintLiquidity: true
        });

        setupTestCase(params);

        vm.expectRevert(encodeError("InsufficientInputAmount()"));
        pool.swap(address(this), "");
    }

    /////////////////////////////////////////
    //                                     //
    //              CALLBACK               //
    //                                     //
    /////////////////////////////////////////

    // It’s the test contract that will provide liquidity and will call the mint
    // function on the pool, there’re no users. The test contract will act as a user,
    // thus it can implement the mint callback function.
    function biswapMintCallback(uint256 amount0, uint256 amount1, bytes calldata data) public {
        if (transferInMintCallback) {
            BiswapPool.CallbackData memory extra = abi.decode(data, (BiswapPool.CallbackData));
            // msg.sender here is the pool contract
            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
        }
    }

    function biswapSwapCallback(int256 amount0, int256 amount1, bytes calldata data) public {
        if (transferInSwapCallback) {
            BiswapPool.CallbackData memory extra = abi.decode(data, (BiswapPool.CallbackData));

            if (amount0 > 0) {
                IERC20(extra.token0).transferFrom(extra.payer, msg.sender, uint256(amount0));
            }

            if (amount1 > 0) {
                IERC20(extra.token1).transferFrom(extra.payer, msg.sender, uint256(amount1));
            }
        }
    }

    /////////////////////////////////////////
    //                                     //
    //              INTERNAL               //
    //                                     //
    /////////////////////////////////////////

    function setupTestCase(TestCaseParams memory params)
        internal
        returns (uint256 poolBalance0, uint256 poolBalance1)
    {
        token0.mint(address(this), params.wethBalance);
        token1.mint(address(this), params.usdcBalance);

        pool = new BiswapPool(
            address(token0),
            address(token1),
            params.currentSqrtP,
            params.currentTick
        );

        if (params.mintLiquidity) {
            token0.approve(address(this), params.wethBalance);
            token1.approve(address(this), params.usdcBalance);

            BiswapPool.CallbackData memory extra =
                BiswapPool.CallbackData({token0: address(token0), token1: address(token1), payer: address(this)});

            (poolBalance0, poolBalance1) =
                pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity, abi.encode(extra));
        }

        transferInMintCallback = params.transferInMintCallback;
        transferInSwapCallback = params.transferInSwapCallback;
    }
}
