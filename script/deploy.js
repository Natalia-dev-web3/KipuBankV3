import dotenv from "dotenv";
dotenv.config();

import { ethers } from "ethers";
import { readFileSync } from "fs";

async function main() {
  console.log("🚀 Desplegando KipuBankV3...\n");
  
  const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
  const privateKey = process.env.PRIVATE_KEY.startsWith('0x') 
    ? process.env.PRIVATE_KEY 
    : '0x' + process.env.PRIVATE_KEY;
  const wallet = new ethers.Wallet(privateKey, provider);
  
  console.log("📍 Desplegando desde:", wallet.address);
  console.log("💰 Balance:", ethers.formatEther(await provider.getBalance(wallet.address)), "ETH\n");
  
  const artifact = JSON.parse(
    readFileSync("./artifacts/contracts/KipuBankV3.sol/KipuBankV3.json", "utf8")
  );
  
  const factory = new ethers.ContractFactory(
    artifact.abi,
    artifact.bytecode,
    wallet
  );
  
  console.log("⏳ Desplegando contrato...\n");
  
  const kipuBank = await factory.deploy(
    "10000000000",
    "1000000000",
    "0x694AA1769357215DE4FAC081bf1f309aDC325306",
    "0xdc8aeC8D26B283F718B1e18B4a189292fF3Dd13A",
    "0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008",
    "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
    { gasLimit: 8000000 }
  );
  
  console.log("⏳ Esperando confirmación...\n");
  await kipuBank.waitForDeployment();
  
  const address = await kipuBank.getAddress();
  
  console.log("✅ KipuBankV3 desplegado en:", address);
  console.log("\n🔗 Ver en Etherscan:");
  console.log(`https://sepolia.etherscan.io/address/${address}\n`);
  console.log("📋 Para verificar:");
  console.log(`npx hardhat verify --network sepolia ${address} 10000000000 1000000000 0x694AA1769357215DE4FAC081bf1f309aDC325306 0xdc8aeC8D26B283F718B1e18B4a189292fF3Dd13A 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
