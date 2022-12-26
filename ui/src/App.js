import "./App.css";
import { MetaMaskProvider } from "./contexts/MetaMask";
import MetaMask from "./components/MetaMask";

function App() {
  return (
    <MetaMaskProvider>
      <div className="App flex flex-col justify-between items-center w-full h-full">
        <MetaMask />
      </div>
    </MetaMaskProvider>
  );
}

export default App;
