// 导入所需的库
const { ethers } = require("ethers");
require("dotenv").config();

const OpGoerli_KEY = process.env.ALCHEMY_OpGoerli_KEY;
const providerBase = new ethers.JsonRpcProvider(
  `https://opt-goerli.g.alchemy.com/v2/${OpGoerli_KEY}`
);

const privateKey =
  "77e7e7d4db6930c32590eb803d74265679c64212de31fbdb178eeb377f0c2525";

const wallet = new ethers.Wallet(privateKey, providerBase);

const abiKeeper = [
  "function checkUpkeep(bytes) view returns (bool,bytes)",
  "function performUpkeep(bytes) public",
];

const addressKeeper = "0xd5eF66B4F8De6B6913D525380a6e3408174d131D";
const contractKeeper = new ethers.Contract(addressKeeper, abiKeeper, wallet);

const queryContractState = async () => {
  try {
    const upkeepNeeded = await contractKeeper.checkUpkeep("0x00");
    let feeData = await providerBase.getFeeData();
    const nonce = await providerBase.getTransactionCount(
      "0xF51585A11f74A45381c7FcaEbc03C102f96971B4"
    );
    console.log(upkeepNeeded[0]);
    if (upkeepNeeded[0] == true) {
      await contractKeeper.performUpkeep("0x00", {
        gasPrice: feeData.gasPrice,
        nonce: nonce,
      });
    }
  } catch (error) {
    console.error("An error occurred:", error.message);
    // 这里可以实现重试逻辑或者其他错误处理逻辑
  }
};

setInterval(queryContractState, 20000);
