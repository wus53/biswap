import { useContext } from "react";
import { MetaMaskContext } from "../contexts/MetaMask";

const chainIdToChain = (chainId) => {
  switch (chainId) {
    case "0x1":
      return "Mainnet";

    case "0x7a69":
      return "Anvil";

    default:
      return "unknown chain";
  }
};

const shortAddress = (address) =>
  address.slice(0, 6) + "..." + address.slice(-4);

const statusConnected = (account, chain) => {
  return (
    <span>
      Connected to {chainIdToChain(chain)} as {shortAddress(account)}
    </span>
  );
};

const statusNotConnected = (connect) => {
  return (
    <span>
      MetaMask is not connected.{" "}
      <button className="bg-violet-200 rounded-xl px-2" onClick={connect}>
        Connect
      </button>
    </span>
  );
};

const renderStatus = (status, account, chain, connect) => {
  switch (status) {
    case "connected":
      return statusConnected(account, chain);

    case "not_connected":
      return statusNotConnected(connect);

    case "not_installed":
      return <span>Metamask is not installed</span>;

    default:
      return;
  }
};

const MetaMask = () => {
  const context = useContext(MetaMaskContext);

  return (
    <section className="bg-white rounded-xl shadow-lg py-4 px-6 mt-6">
      {renderStatus(
        context.status,
        context.account,
        context.chain,
        context.connect
      )}
    </section>
  );
};

export default MetaMask;
