const { network } = require('hardhat');
const hre = require('hardhat');

const provider = hre.ethers.provider;
async function main() {
  const gasPrice = await provider.getGasPrice();
  // console.log(
  //   'Gas price on',
  //   network,
  //   hre.ethers.utils.formatEther(gasPrice, 'gwei'),
  //   'gwei'
  // );
  console.log(  network);

  const Royalty = await hre.ethers.getContractFactory('Royalty');
  const royalty = await Royalty.deploy();
  await royalty.deployed();

  console.log(`Airdrp deployed at ${royalty.address} in network: ${network}.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
