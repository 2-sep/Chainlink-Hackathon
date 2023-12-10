// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const PancakePrediction = await hre.ethers.getContractFactory("EggCrowns");
  const contract = await PancakePrediction.deploy(
    "0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada",
    "0x29C05AE3B3a11D4618562D92148eBF4b84C25fBA",
    "0xF51585A11f74A45381c7FcaEbc03C102f96971B4",
    300,
    40,
    hre.ethers.parseUnits("0.001", "ether").toString(),
    300,
    300
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
