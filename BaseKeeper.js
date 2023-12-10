// 导入所需的库
const { ethers } = require("ethers");
require("dotenv").config();

const BaseGoerli_KEY = process.env.ALCHEMY_BaseGoerli_KEY;
const providerBase = new ethers.JsonRpcProvider(
  `https://base-goerli.g.alchemy.com/v2/${BaseGoerli_KEY}`
);

const privateKey =
  "77e7e7d4db6930c32590eb803d74265679c64212de31fbdb178eeb377f0c2525";

const wallet = new ethers.Wallet(privateKey, providerBase);

const abiKeeper = [
  "function checkUpkeep(bytes) view returns (bool,bytes)",
  "function performUpkeep(bytes) public",
];

const addressKeeper = "0x9ca96D8967af98a1cA3179c558640Cb709aC51CD";
const contractKeeper = new ethers.Contract(addressKeeper, abiKeeper, wallet);

let lastUpkeepNeeded = false;
let intervalId;

const queryContractState = async () => {
  try {
    const upkeepNeeded = await contractKeeper.checkUpkeep("0x00");
    console.log(upkeepNeeded[0]);

    if (upkeepNeeded[0] != lastUpkeepNeeded) {
      if (upkeepNeeded[0]) {
        // 如果upkeepNeeded从false变为true，重置定时器为每10秒执行一次
        clearInterval(intervalId);
        intervalId = setInterval(queryContractState, 10000);
      } else {
        // 如果upkeepNeeded从true变为false，等待19分钟后执行
        clearInterval(intervalId);
        setTimeout(() => {
          intervalId = setInterval(queryContractState, 10000);
        }, 1140000); //
      }
    }

    lastUpkeepNeeded = upkeepNeeded[0];

    if (upkeepNeeded[0] == true) {
      let feeData = await providerBase.getFeeData();
      const nonce = await providerBase.getTransactionCount(wallet.address);
      await contractKeeper.performUpkeep("0x00", {
        gasPrice: feeData.gasPrice,
        nonce: nonce,
      });
    }
  } catch (error) {
    console.error("An error occurred:", error.message);
  }
};

intervalId = setInterval(queryContractState, 20000); // 初始定时器设定为每20秒
