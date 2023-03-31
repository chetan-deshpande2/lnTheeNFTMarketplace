require('@nomicfoundation/hardhat-toolbox');
require('@nomiclabs/hardhat-etherscan');
require('hardhat-gas-reporter');
require('dotenv').config();
require('solidity-coverage');

const {
  PRIVATE_KEY,
  PRIVATE_KEY2,
  POLYGON_API_KEY,
  POLYGON_RPC_URL,
  ETHEREUM_API_KEY,
  BINANCE_API_KEY,
} = process.env;

task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(process.env.POLYGON_RPC_URL);
  }
});

module.exports = {
  solidity: {
    version: '0.8.16',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  gasReporter: {
    currency: 'MATIC',
    gasPrice: 21,
  },
  plugins: ['solidity-coverage'],

  networks: {
    hardhat: {},
    ethereumMainnet: {
      url: 'https://eth-mainnet.g.alchemy.com/v2/T6UkWrU2qhiuxKJXWjFTMNURkc74xtbp',
      accounts: [PRIVATE_KEY],
    },
    goerliTestnet: {
      url: 'https://eth-goerli.g.alchemy.com/v2/KinLNLcEoSgPTt8pYT49ZbVlQxYBz0Cm',
      accounts: [PRIVATE_KEY2],
    },
    sepoliaTestnet: {
      url: 'https://eth-sepolia.g.alchemy.com/v2/HaLHCh_p9--LqitAAC8Dca1SdDFXuBAn',
      accounts: [PRIVATE_KEY],
    },
    polygonMainnet: {
      url: 'https://polygon-mumbai.g.alchemy.com/v2/_ULp5HCwK_YWhB3OfsvTU64A8G9A0KsY',
      account: [PRIVATE_KEY],
    },

    polygonTestnet: {
      url: POLYGON_RPC_URL,
      accounts: [PRIVATE_KEY],
    },

    bscMainnet: {
      url: 'https://bsc-dataseed.binance.org/',
      accounts: [PRIVATE_KEY],
    },
    bscTestnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      accounts: [PRIVATE_KEY],
    },
    harmonyMainnet: {
      url: `https://api.harmony.one`,
      accounts: [PRIVATE_KEY],
    },
    harmonyTestnet: {
      url: `https://api.s0.b.hmny.io`,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    // apiKey: {
    //   goerli: ETHEREUM_API_KEY || '',
    //   polygon: POLYGON_API_KEY || '',
    //   binance: '',
    //   harmony: '',
    // },
    // apiKey: POLYGON_API_KEY,
    // apiKey: BINANCE_API_KEY,
    apiKey: ETHEREUM_API_KEY,
  },
};
