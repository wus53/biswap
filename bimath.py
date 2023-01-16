import math

min_tick = -887272
max_tick = 887272

q96 = 2**96
eth = 10**18


def price_to_tick(p):
    return math.floor(math.log(p, 1.0001))


def price_to_sqrtp(p):
    return int(math.sqrt(p) * q96)


def tick_to_sqrtp(t):
    return int((1.0001 ** (t / 2)) * q96)


def liquidity0(amount, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return (amount * (pa * pb) / q96) / (pb - pa)


def liquidity1(amount, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return amount * q96 / (pb - pa)


def calc_amount0(liq, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return int(liq * q96 * (pb - pa) / pa / pb)


def calc_amount1(liq, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return int(liq * (pb - pa) / q96)


# Liquidity provision
price_low = 4545
price_cur = 5000
price_upp = 5500

print("Price range: {}-{}; current price: {}".format(price_low, price_upp, price_cur))

sqrtp_low = price_to_sqrtp(price_low)
sqrtp_cur = price_to_sqrtp(price_cur)
sqrtp_upp = price_to_sqrtp(price_upp)

amount_eth = 1 * eth
amount_usdc = 5000 * eth

liq0 = liquidity0(amount_eth, sqrtp_cur, sqrtp_upp)
liq1 = liquidity1(amount_usdc, sqrtp_cur, sqrtp_low)
liq = int(min(liq0, liq1))

print("Deposit: {} ETH, {} USDC; liquidity: {}".format(amount_eth/eth, amount_usdc/eth, liq))

# Swap USDC for ETH
amount_in = 42 * eth

print("Selling {} USDC".format(amount_in/eth))

price_diff = (amount_in * q96) // liq
price_next = sqrtp_cur + price_diff

print("New price: {}".format((price_next / q96) ** 2))
print("New sqrtP: {}".format(price_next))
print("New tick: {}".format(price_to_tick((price_next / q96) ** 2)))

amount_in = calc_amount1(liq, price_next, sqrtp_cur)
amount_out = calc_amount0(liq, price_next, sqrtp_cur)

print("USDC in: {}".format(amount_in / eth))
print("ETH out: {}".format(amount_out / eth))


# Price range: 4545-5500; current price: 5000
# Deposit: 1.0 ETH, 5000.0 USDC; liquidity: 1517882343751509868544
# Selling 42.0 USDC
# New price: 5003.913912782393
# New sqrtP: 5604469350942327889444743441197
# New tick: 85184
# USDC in: 42.0
# ETH out: 0.008396714242162444


# Swap ETH for USDC
amount_in = 0.01337 * eth

print("\nSelling {} ETH".format(amount_in/eth))

price_next = int((liq * q96 * sqrtp_cur) // (liq * q96 + amount_in * sqrtp_cur))

print("New price:", (price_next / q96) ** 2)
print("New sqrtP", price_next)
print("New tick:", price_to_tick((price_next / q96) ** 2))

amount_in = calc_amount0(liq, price_next, sqrtp_cur)
amount_out = calc_amount1(liq, price_next, sqrtp_cur)

print("ETH in:", amount_in / eth)
print("USDC out:", amount_out / eth)

# Selling 0.01337 ETH
# New price: 4993.777388290041
# New sqrtP 5598789932670289186088059666432
# New tick: 85163
# ETH in: 0.013369999999998142
# USDC out: 66.80838889019013
