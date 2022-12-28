import { ethers } from "ethers";
import { useContext, useEffect, useState, useReducer } from "react";
import { MetaMaskContext } from "../contexts/MetaMask";

const PoolABI = require("../abi/Pool.json");

const getEvents = (pool) => {
  return Promise.all([
    pool.queryFilter("Mint", "earliest", "latest"),
    pool.queryFilter("Swap", "earliest", "latest"),
  ]).then(([mints, swaps]) => {
    return Promise.resolve((mints || []).concat(swaps || []));
  });
};

const subscribeToEvents = (pool, callback) => {
  // pool.on("Mint", (sender, owner, tickLower, tickUpper, amount, amount0, amount1, event) => callback(event));
  // pool.on("Swap", (sender, recipient, amount0, amount1, sqrtPriceX96, liquidity, tick, event) => callback(event));
  pool.once("Mint", (a, b, c, d, e, f, g, event) => callback(event));
  pool.once("Mint", (a, b, c, d, e, f, g, event) => callback(event));
};

const renderAmount = (amount) => {
  return ethers.utils.formatUnits(amount);
};

const renderMint = (args) => {
  return (
    <span>
      <strong>Mint</strong>
      [range: [{args.lowerTick} - {args.upperTick}], amounts: [
      {renderAmount(args.amount0)}, {renderAmount(args.amount1)}]]
    </span>
  );
};

const renderSwap = (args) => {
  return (
    <span>
      <strong>Swap</strong>
      [amount0: {renderAmount(args.amount0)}, amount1:{" "}
      {renderAmount(args.amount1)}]
    </span>
  );
};

const renderEvent = (event, i) => {
  let content;

  switch (event.event) {
    // if we do not have break before cases: https://eslint.org/docs/latest/rules/no-fallthrough
    case "Mint":
      content = renderMint(event.args);
      break;
    case "Swap":
      content = renderSwap(event.args);
      break;
    default:
      break;
  }

  return <li key={i}>{content}</li>;
};

const isMintOrSwap = (event) => {
  return event.event === "Mint" || event.event === "Swap";
};

// read twice
const cleanEvents = (events) => {
  return events
    .sort((a, b) => b.blockNumber - a.blockNumber)
    .filter((el, i, arr) => {
      return (
        i === 0 ||
        el.blockNumber !== arr[i - 1].blockNumber ||
        el.logIndex !== arr[i - 1].logIndex
      );
    });
};

const eventsReducer = (state, action) => {
  switch (action.type) {
    case "add":
      return cleanEvents([action.value, ...state]);

    case "set":
      return cleanEvents(action.value);
    default:
      return;
  }
};

const EventsFeed = (props) => {
  const config = props.config;
  const metamaskContext = useContext(MetaMaskContext);
  const [events, setEvents] = useReducer(eventsReducer, []);
  const [pool, setPool] = useState();

  useEffect(() => {
    if (metamaskContext.status !== "connected") {
      return;
    }

    if (!pool) {
      const newPool = new ethers.Contract(
        config.poolAddress,
        PoolABI,
        new ethers.providers.Web3Provider(window.ethereum)
      );

      subscribeToEvents(newPool, (event) =>
        setEvents({ type: "add", value: event })
      );

      getEvents(newPool).then((events) => {
        setEvents({ type: "set", value: events });
      });

      setPool(newPool);
    }
  }, [metamaskContext.status, events, pool, config]);

  return (
    <ul className="py-6">{events.filter(isMintOrSwap).map(renderEvent)}</ul>
  );
};

export default EventsFeed;
