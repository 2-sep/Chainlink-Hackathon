// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const PancakePrediction = await hre.ethers.getContractFactory("OpEggCrowns");

  const options = {
    gasPrice: hre.ethers.parseUnits("10", "gwei"),
  };

  const contract = await PancakePrediction.deploy(
    "0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8", //oracleAddress
    "0xF51585A11f74A45381c7FcaEbc03C102f96971B4", //adminAddress
    "0xd5eF66B4F8De6B6913D525380a6e3408174d131D", //operatorAddress
    1200, //intervalSeconds
    40, //bufferSeconds
    hre.ethers.parseUnits("0.001", "ether").toString(), //minPredictAmount
    300, //oracleUpdateAllowance
    300, //treasuryFee
    "0xcc5a0b910d9e9504a7561934bed294c51285a78d", //RouterAddress
    "0xdc2CC710e42857672E7907CF474a69B63B93089f", //LinkAddress
    "5790810961207155433", //destinationChainSelector
    "0x2F630463096843b0C3709d7bE9D16D69C70E8ad8", //目标链 Base链receiver
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
