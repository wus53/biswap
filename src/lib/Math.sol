// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.14;

import "./FixedPoint96.sol";
import "prb-math/PRBMath.sol";

library Math {
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = PRBMath.mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            // prevent overflow
            require(result < type(uint256).max);
            result++;
        }
    }

    function divRoundingUp(
        uint256 numerator,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        assembly {
            result := add(
                div(numerator, denominator),
                gt(mod(numerator, denominator), 0)
            )
        }
    }

    /// @notice Calculates amount0 delta between two prices following the formula
    /// @dev https://uniswapv3book.com/docs/milestone_2/generalize-minting/
    /// TODO: round down when removing liquidity
    function calcAmount0Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        // sort the prices to ensure we don’t underflow when subtracting
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        require(sqrtPriceAX96 > 0);

        // using mulDivRoundingUp to avoid overflows during multiplication
        amount0 = divRoundingUp(
            mulDivRoundingUp(
                // convert liquidity to a Q96.64 number by multiplying it by 2**96.
                (uint256(liquidity) << FixedPoint96.RESOLUTION),
                (sqrtPriceBX96 - sqrtPriceAX96),
                sqrtPriceBX96
            ),
            sqrtPriceAX96
        );
    }

    /// @notice Calculates amount1 delta between two prices following the fomula
    /// @dev https://uniswapv3book.com/docs/milestone_2/generalize-minting/
    /// TODO: round down when removing liquidity
    function calcAmount1Delta(
        uint160 sqrtPriceAX96,
        uint160 sqrtPriceBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        // sort the prices to ensure we don't underflow when subtracting
        if (sqrtPriceAX96 > sqrtPriceBX96)
            (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

        require(sqrtPriceAX96 > 0);

        // using mulDivRoundingUp to avoid overflows during multiplication
        amount1 = mulDivRoundingUp(
            liquidity,
            (sqrtPriceBX96 - sqrtPriceAX96),
            FixedPoint96.Q96
        );
    }

    // When amount_in is token0
    // price_next = int((liq * q96 * sqrtp_cur) // (liq * q96 + amount_in * sqrtp_cur))
    // When amount_in is token1
    // price_next = sqrtp_cur + (amount_in * q96) // liq
    function getNextSqrtPriceFromInput(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtPriceNextX96) {
        sqrtPriceNextX96 = zeroForOne
            ? getNextSqrtPriceFromAmount0RoundingUp(
                sqrtPriceX96,
                liquidity,
                amountIn
            )
            : getNextSqrtPriceFromAmount1RoundingDown(
                sqrtPriceX96,
                liquidity,
                amountIn
            );
    }

    // price_next = int((liq * q96 * sqrtp_cur) // (liq * q96 + amount_in * sqrtp_cur))
    function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn
    ) internal pure returns (uint160) {
        uint256 numerator = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 product = amountIn * sqrtPriceX96;

        if (product / amountIn == sqrtPriceX96) {
            uint256 denominator = numerator + product;
            if (denominator >= numerator) {
                return
                    uint160(
                        mulDivRoundingUp(numerator, sqrtPriceX96, denominator)
                    );
            }
        }

        // When the above formula overflows, we use an alternative
        // formula, which is less precise:
        // formula detail at https://uniswapv3book.com/docs/milestone_2/generalize-swapping/
        return
            uint160(
                divRoundingUp(numerator, (numerator / sqrtPriceX96) + amountIn)
            );
    }

    // price_next = sqrtp_cur + (amount_in * q96) // liq
    function getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPriceX96,
        uint128 liquidity,
        uint256 amountIn
    ) internal pure returns (uint160) {
        return
            sqrtPriceX96 +
            uint160((amountIn << FixedPoint96.RESOLUTION) / liquidity);
    }
}
