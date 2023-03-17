const { network } = require('hardhat');
const hre = require('hardhat');

const PaymentTokenAddress = {
  bsctestnet: '0xae13d989dac2f0debff460ac112a837c89baa7cd',
  bsc: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
  matic: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270', // WMATIC
  mumbai: '',
  eth: '0x418D75f65a02b3D53B2418FB8E1fe493759c7605',
  harmony: '0xb1f6E61E1e113625593a22fa6aa94F8052bc39E0',
  harmonyDev:''
};

const provider = hre.ethers.provider;
async function main() {
  const gasPrice = await provider.getGasPrice();
  // console.log(
  //   'Gas price on',
  //   network,
  //   hre.ethers.utils.formatEther(gasPrice, 'gwei'),
  //   'gwei'
  // );
  // console.log( network)
  //   if (network === 'deployment') {
  const ERC721 = await hre.ethers.getContractFactory('TestERC721');
  let erc721 = await ERC721.deploy();
  await erc721.deployed();
  console.log(
    `TestERC721 deployed at ${erc721.address} in network: ${network}.`
  );
  const ERC20 = await hre.ethers.getContractFactory('TestERC20');
  const erc20 = await ERC20.deploy();
  await erc20.deployed();

  console.log(`TestERC20 deployed at ${erc20.address} in network: ${network}.`);

  const Marketplace = await hre.ethers.getContractFactory('Marketplace');

  const marketplace = await Marketplace.deploy(erc20.address);
  await marketplace.deployed();

  console.log(
    `Marketplace deployed at ${marketplace.address} in network: ${network}.`
  );
  //   }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
