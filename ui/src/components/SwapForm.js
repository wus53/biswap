import "./SwapForm.css";
import { ethers } from "ethers";
import { useContext, useEffect, useState } from "react";
import { MetaMaskContext } from "../contexts/MetaMask";
import config from "../config.js";
import debounce from "../lib/debounce";

const uint256Max = ethers.constants.MaxUint256;
const pairs = [["WETH", "USDC"]];

const addLiquidity = (account, { token0, token1, manager }) => {
  if (!token0 || !token1) {
    return;
  }

  const amount0 = ethers.utils.parseEther("0.998976618347425280");
  const amount1 = ethers.utils.parseEther("5000"); // 5000 USDC

  const lowerTick = 84222;
  const upperTick = 86129;
  const liquidity = ethers.BigNumber.from("1517882343751509868544");
  const extra = ethers.utils.defaultAbiCoder.encode(
    ["address", "address", "address"],
    [token0.address, token1.address, account]
  );

  Promise.all([
    token0.allowance(account, config.managerAddress),
    token1.allowance(account, config.managerAddress),
  ])
    .then(([allowance0, allowance1]) => {
      return Promise.resolve()
        .then(() => {
          if (allowance0.lt(amount0)) {
            return token0
              .approve(config.managerAddress, uint256Max)
              .then((tx) => tx.wait());
          }
        })
        .then(() => {
          if (allowance1.lt(amount1)) {
            return token1
              .approve(config.managerAddress, uint256Max)
              .then((tx) => tx.wait());
          }
        })
        .then(() => {
          return manager
            .mint(config.poolAddress, lowerTick, upperTick, liquidity, extra)
            .then((tx) => tx.wait());
        })
        .then(() => {
          alert("Liquidity Added!");
        });
    })
    .catch((err) => {
      console.error(err);
      alert("Add Liquidity Failed!");
    });
};

const swap = (
  amountIn,
  zeroForOne,
  account,
  { tokenIn, manager, token0, token1 }
) => {
  const amountInWei = ethers.utils.parseEther(amountIn);
  const extra = ethers.utils.defaultAbiCoder.encode(
    ["address", "address", "address"],
    [token0.address, token1.address, account]
  );

  tokenIn
    .allowance(account, config.managerAddress)
    .then((allowance) => {
      if (allowance.lt(amountInWei)) {
        return tokenIn
          .approve(config.managerAddress, uint256Max)
          .then((tx) => tx.wait());
      }
    })
    .then(() => {
      return manager
        .swap(config.poolAddress, zeroForOne, amountInWei, extra)
        .then((tx) => tx.wait());
    })
    .then(() => {
      alert("Swap succeeded!");
    })
    .catch((err) => {
      console.error(err);
      alert("Swap Failed!");
    });
};

const SwapInput = ({ token, amount, setAmount, disabled, readOnly }) => {
  return (
    <fieldset disabled={disabled} className="mb-1 flex flex-row">
      <input
        type="text"
        id={token + "_amount"}
        placeholder="0.0"
        value={amount}
        onChange={(e) => setAmount(e.target.value)}
        readOnly={readOnly}
        className="pixelated-border w-2/3"
      />
      <label
        htmlFor={token + "_amount"}
        className="pixelated-border w-1/3 text-center pt-3"
      >
        {token}
      </label>
    </fieldset>
  );
};

const ChangeDirectionButton = ({ zeroForOne, setZeroForOne, disabled }) => {
  return (
    <span
      className="text-2xl cursor-pointer select-none w-1/4 text-center bg-pink-300 pt-2 mx-auto pixelated-border mt-1 mb-4"
      onClick={(e) => {
        e.preventDefault();
        setZeroForOne(!zeroForOne);
      }}
      disabled={disabled}
    >
      🔄
    </span>
  );
};

const SwapForm = () => {
  const metamaskContext = useContext(MetaMaskContext);
  const enabled = metamaskContext.status === "connected";

  const pair = pairs[0];

  const [zeroForOne, setZeroForOne] = useState(true);
  const [amount0, setAmount0] = useState();
  const [amount1, setAmount1] = useState();
  const [token0, setToken0] = useState();
  const [token1, setToken1] = useState();
  const [manager, setManager] = useState();
  const [quoter, setQuoter] = useState();
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    setToken0(
      new ethers.Contract(
        config.token0Address,
        config.ABIs.ERC20,
        new ethers.providers.Web3Provider(window.ethereum).getSigner()
      )
    );
    setToken1(
      new ethers.Contract(
        config.token1Address,
        config.ABIs.ERC20,
        new ethers.providers.Web3Provider(window.ethereum).getSigner()
      )
    );
    setManager(
      new ethers.Contract(
        config.managerAddress,
        config.ABIs.Manager,
        new ethers.providers.Web3Provider(window.ethereum).getSigner()
      )
    );
    setQuoter(
      new ethers.Contract(
        config.quoterAddress,
        config.ABIs.Quoter,
        new ethers.providers.Web3Provider(window.ethereum).getSigner()
      )
    );
  }, []);

  const addLiquidity_ = () => {
    addLiquidity(metamaskContext.account, { token0, token1, manager });
  };

  const swap_ = (e) => {
    // submit button prevent default refresh
    e.preventDefault();
    swap(zeroForOne ? amount0 : amount1, zeroForOne, metamaskContext.account, {
      tokenIn: token1,
      manager,
      token0,
      token1,
    });
  };

  const updateAmountOut = debounce((amount) => {
    if (amount === 0 || amount === "0") {
      return;
    }

    // console.log(quoter);
    // console.log(manager);

    setLoading(true);

    quoter.callStatic
      .quote({
        pool: config.poolAddress,
        amountIn: ethers.utils.parseEther(amount),
        zeroForOne: zeroForOne,
      })
      .then(({ amountOut }) => {
        zeroForOne
          ? setAmount1(ethers.utils.formatEther(amountOut))
          : setAmount0(ethers.utils.formatEther(amountOut));
        setLoading(false);
      })
      .catch((err) => {
        zeroForOne ? setAmount1(0) : setAmount0(0);
        setLoading(false);
        console.error(err);
      });
  });

  const setAmount_ = (setAmountFn) => {
    return (amount) => {
      amount = amount || 0;
      setAmountFn(amount);
      updateAmountOut(amount);
    };
  };

  return (
    <section className="SwapContainer pixelated-border">
      <header>
        <h1>Swap Tokens</h1>
        <button disabled={!enabled} onClick={addLiquidity_}>
          Add liquidity
        </button>
      </header>
      <form className="SwapForm">
        <SwapInput
          amount={zeroForOne ? amount0 : amount1}
          setAmount={setAmount_(zeroForOne ? setAmount0 : setAmount1)}
          token={zeroForOne ? pair[0] : pair[1]}
          disabled={!enabled || loading}
          readOnly={false}
        />
        <ChangeDirectionButton
          zeroForOne={zeroForOne}
          setZeroForOne={setZeroForOne}
          disabled={!enabled || loading}
        />
        <SwapInput
          amount={zeroForOne ? amount1 : amount0}
          disabled={!enabled || loading}
          readOnly={true}
          token={zeroForOne ? pair[1] : pair[0]}
        />
        <button
          disabled={!enabled}
          onClick={swap_}
          className="pixelated-border"
        >
          Swap
        </button>
      </form>
    </section>
  );
};

export default SwapForm;
