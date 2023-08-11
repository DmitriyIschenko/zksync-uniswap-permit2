import { Provider, Contract, Wallet } from "zksync-web3";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import * as hre from "hardhat";
import * as fs from "fs";
import { HttpNetworkConfig } from "hardhat/types";

const RICH_WALLET_PRIVATE_KEYS = JSON.parse(
  fs.readFileSync(`test/zksync-tests/shared/rich-wallets.json`, "utf8"),
);

export const provider = new Provider(
  (hre.network.config as HttpNetworkConfig).url,
);

const wallet = new Wallet(RICH_WALLET_PRIVATE_KEYS[0].privateKey, provider);
const deployer = new Deployer(hre, wallet);

export function getWallets(): Wallet[] {
  let wallets = [];
  for (let i = 0; i < RICH_WALLET_PRIVATE_KEYS.length; i++) {
    wallets[i] = new Wallet(RICH_WALLET_PRIVATE_KEYS[i].privateKey, provider);
  }
  return wallets;
}

export async function loadArtifact(name: string) {
  return await deployer.loadArtifact(name);
}

export async function deployContract(
  name: string,
  constructorArguments?: any[] | undefined,
): Promise<Contract> {
  const artifact = await loadArtifact(name);
  return await deployer.deploy(artifact, constructorArguments);
}
