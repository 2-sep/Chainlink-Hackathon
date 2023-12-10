// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const PancakePrediction = await hre.ethers.getContractFactory(
    "BaseEggCrowns"
  );

  const options = {
    gasPrice: hre.ethers.parseUnits("10", "gwei"),
  };
  const contract = await PancakePrediction.deploy(
    "0xcD2A119bD1F7DF95d706DE6F2057fDD45A0503E2", //oracleAddress
    "0xF51585A11f74A45381c7FcaEbc03C102f96971B4", //adminAddress
    "0x9ca96D8967af98a1cA3179c558640Cb709aC51CD", //operatorAddress
    1200, //intervalSeconds
    40, //bufferSeconds
    hre.ethers.parseUnits("0.001", "ether").toString(), //minPredictAmount
    300, //oracleUpdateAllowance
    300, //treasuryFee
    "0x80af2f44ed0469018922c9f483dc5a909862fdc2", //RouterAddress
    "0x6d0f8d488b669aa9ba2d0f0b7b75a88bf5051cd3", //LinkAddress
    // "2664363617261496610", //destinationChainSelector
    // "0x71C9144A499De3AF10d4f50e920120920F2867e7", //目标链 Op链receiver
    options
  );
  // await contract.deployed()
  await contract.waitForDeployment();
  // console.log("Contract deployed to:", BatchMintClips_contract.address)
  console.log("Contract deployed to:", await contract.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
