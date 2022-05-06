// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const StakingContract = await ethers.getContractFactory('Staking')
  const stakingContract = await StakingContract.deploy('0x4972248fA459CF7C4c511154071a14775Eb4e2F2', '0x9bE6733a759c24F7d0Eb53D0C65CaDf1A896deF5');
  await stakingContract.deployed()
  console.log("stakingContract deployed to:", stakingContract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});