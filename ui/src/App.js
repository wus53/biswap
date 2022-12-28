import "./App.css";
import { MetaMaskProvider } from "./contexts/MetaMask";
import MetaMask from "./components/MetaMask";
import SwapForm from "./components/SwapForm";
import EventsFeed from "./components/EventsFeed";

const config = {
  token0Address: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  token1Address: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
  poolAddress: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
  managerAddress: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
  ABIs: {
    ERC20: require("./abi/ERC20.json"),
    Pool: require("./abi/Pool.json"),
    Manager: require("./abi/Manager.json"),
  },
};

function App() {
  return (
    <MetaMaskProvider>
      <div className="App flex flex-col justify-between items-center w-full h-full">
        <MetaMask />
        <div className="w-1/6">
          <img src="logo.png" alt="logo" />
        </div>
        <SwapForm config={config} />
        <footer>
          <EventsFeed config={config} />
        </footer>
      </div>
    </MetaMaskProvider>
  );
}

export default App;
