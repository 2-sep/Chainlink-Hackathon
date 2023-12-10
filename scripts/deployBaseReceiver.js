// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const PancakePrediction = await hre.ethers.getContractFactory("BaseReceiver");
  const contract = await PancakePrediction.deploy(
    "0x80af2f44ed0469018922c9f483dc5a909862fdc2", //CCIP Router Address
    "0x7e829540c1f17E274dE386c67548783BdbF71D7A" //Contracts Address
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
