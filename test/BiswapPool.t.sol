//SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../src/BiswapPool.sol";
import "./ERC20Mintable.sol";

contract BiswapPoolTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    BiswapPool pool;

    bool shouldTransferInCallback = true;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool shouldTransferInCallback;
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
            shouldTransferInCallback: true,
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

    /////////////////////////////////////////
    //                                     //
    //              CALLBACK               //
    //                                     //
    /////////////////////////////////////////

    bool success;

    // It’s the test contract that will provide liquidity and will call the mint
    // function on the pool, there’re no users. The test contract will act as a user,
    // thus it can implement the mint callback function.
    function biswapMintCallback(uint256 amount0, uint256 amount1) public {
        if (shouldTransferInCallback) {
            // msg.sender here is the pool contract
            token0.transfer(msg.sender, amount0);
            token1.transfer(msg.sender, amount1);
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
            (poolBalance0, poolBalance1) =
                pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity);
        }

        shouldTransferInCallback = params.shouldTransferInCallback;
    }
}
