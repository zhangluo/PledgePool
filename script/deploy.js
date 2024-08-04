const { ethers } = require('ethers');
const fs = require('fs');
require('dotenv').config();

async function main() {
    const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

    // Read ABI and bytecode from files
    const contractPath = 'bin/src/PledgePool.json'; // Update with your actual contract path
    const contractJson = JSON.parse(fs.readFileSync(contractPath, 'utf8'));

    const abi = contractJson.abi;
    const bytecode = contractJson.bytecode;

    // Validate ABI and bytecode
    console.log("Contract ABI:", abi);
    console.log("Contract Bytecode:", bytecode);

    // Create contract factory
    const factory = new ethers.ContractFactory(abi, bytecode, wallet);

    // Token address to be passed to the constructor
    const tokenAddress = process.env.TOKEN_ADDRESS; // Make sure this is set in your .env file

    console.log('Deploying contract...');

    // Deploy contract with token address
    const contract = await factory.deploy(tokenAddress);

    // Check if deployTransaction is available
    if (contract) {
        // console.log("Deployment transaction hash:", contract.deployTransaction.hash);
        
        // // Wait for the deployment transaction to be mined
        // const receipt = await provider.waitForTransaction(contract.deployTransaction.hash);
        console.log("Contract deployed to address:", contract);
        // console.log("Transaction hash:", receipt.transactionHash);
        // console.log("Block number:", receipt.blockNumber);
    } else {
        console.log("Deployment transaction not found. Contract might have been deployed but deployTransaction is undefined.");
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
