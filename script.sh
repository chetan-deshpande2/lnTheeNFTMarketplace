#!/bin/bash

#*Before Runnint this script please make sure you have sufficent balnace with associate Account

output1="\nContracts Deployed  on Polygon Testnet"

polygonContracts=$(eval "npx hardhat run scripts/deploy.js --network polygonTestnet")

output1="\nContracts Deployed  on BSC Testnet"

bscContracts=$(eval "npx hardhat run scripts/deploy.js --network bscTestnet")

output1="\nContracts Deployed  on Ethereum sepolia  Testnet"

sepoliaTestnet=$(eval "npx hardhat run scripts/deploy.js --network sepoliaTestnet")

output1="\nContracts on Harmony Testnet"

harmonyContracts=$(eval "npx hardhat run scripts/deploy.js --network harmonyTestnet")

function outputFile() {
    if [ -f "output.txt" ]; then
        # Append output to file
        echo "$output1" >>output.txt
        echo "$polygonContracts" >>output.txt
        echo "$bscContracts" >>output.txt
        echo "$sepoliaTestnet" >>output.txt
        echo "$harmonyContracts" >>output.txt

    else
        # Create new file and write output to it
        echo "$output1" >>output.txt
        echo "$polygonContracts" >>output.txt
        echo "$bscContracts" >>output.txt
        echo "$sepoliaTestnet" >>output.txt
        echo "$harmonyContracts" >>output.txt
    fi

    echo "Contract Address saved to output.txt"

}

outputFile
