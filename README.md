# Biswap

![IMG1597](https://user-images.githubusercontent.com/118578313/209415560-832a90f4-c283-466d-8e0d-12affa878bcb.jpeg)

<p align="center">
  Bi(corn)swap DEX 🔁
</p>

## Deployment

Run Anvil in a separate terminal window

```shell
anvil
```

Activate direnv environment variables in .envrc

```shell
direnv allow
eval "$(direnv hook zsh)"
```

```shell
forge script scripts/DeployDevelopment.s.sol --broadcast --fork-url $ETH_RPC_URL --private-key $PRIVATE_KEY
```

## Milestone 1

In this milestone, I built a pool contract that can receive liquidity from users and make swaps within a price range. To keep it as simple as possible, I'll provide liquidity only in one price range and I'll allow to make swaps only in one direction. Also, I'll calculate all the required math manually to get better intuition before starting using mathematical libs in Solidity.

![16021672194987_ pic](https://user-images.githubusercontent.com/118578313/209748898-496f03e5-cf9e-4bee-a218-6e084d9c944e.jpg)
![16031672194997_ pic](https://user-images.githubusercontent.com/118578313/209748899-08c0d6a7-bd9c-45cc-a79d-7139d0249d8c.jpg)

## Milestone 2

- Installing [prb-math](https://github.com/paulrberg/prb-math) library advanced fixed-point math algorithms.
- In the folder "/lib/prb-math", run the command `git checkout e33a042e4d1673fe9b333830b75c4765ccf3f5f2` to use the previous version of PRB Math library.

![16881676504563_ pic](https://user-images.githubusercontent.com/118578313/219220242-f7b3331f-afdb-4850-abb9-b71c835e316c.jpg)

