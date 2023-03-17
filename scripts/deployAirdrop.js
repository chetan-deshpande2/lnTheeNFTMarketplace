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
  console.log(network);

  const AirdropERC20 = await hre.ethers.getContractFactory('AirdropERC20');
  const airdropERC20 = await AirdropERC20.deploy();
  await airdropERC20.deployed();

  console.log(`Airdrop deployed at ${airdropERC20.address} in network: ${network}.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
