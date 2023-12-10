require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");

//在配置文件中引用
require("dotenv").config();

let ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY || "";
let PRIVATE_KEY = process.env.PRIVATE_KEY || "";
let ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
let ALCHEMY_Mumbai_KEY = process.env.ALCHEMY_Mumbai_KEY || "";
let POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY || "";
let ALCHEMY_BaseGoerli_KEY = process.env.ALCHEMY_BaseGoerli_KEY || "";
let ALCHEMY_OpGoerli_KEY = process.env.ALCHEMY_OpGoerli_KEY || "";
let BASESCAN_API_KEY = process.env.BASESCAN_API_KEY || "";
let OPSCAN_API_KEY = process.env.OPSCAN_API_KEY;

module.exports = {
  // solidity: "0.8.9",
  // 配置网络
  networks: {
    hardhat: {},
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
      accounts: [PRIVATE_KEY],
    },
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${ALCHEMY_Mumbai_KEY}`,
      accounts: [PRIVATE_KEY],
    },
    basegoerli: {
      url: `https://base-goerli.g.alchemy.com/v2/${ALCHEMY_BaseGoerli_KEY}`,
      accounts: [PRIVATE_KEY],
    },
    opgoerli: {
      url: `https://opt-goerli.g.alchemy.com/v2/${ALCHEMY_OpGoerli_KEY}`,
      accounts: [PRIVATE_KEY],
    },
  },
  // 配置自动化verify相关
  etherscan: {
    apiKey: {
      goerli: ETHERSCAN_API_KEY,
      polygonMumbai: POLYGONSCAN_API_KEY,
      baseGoerli: BASESCAN_API_KEY,
      optimisticGoerli: OPSCAN_API_KEY,
    },
  },
  // 配置编译器版本
  solidity: {
    version: "0.8.19",
    // version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
};
