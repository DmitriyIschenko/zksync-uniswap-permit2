import "@matterlabs/hardhat-zksync-deploy";
import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-verify";
import "@nomicfoundation/hardhat-toolbox";
import { task } from "hardhat/config";
import deploy from "./script/deploy";

task("deploy")
  .addParam("privateKey", "Private key used to deploy")
  .setAction(async (taskArgs) => {
    await deploy(taskArgs);
  });

export default {
  networks: {
    hardhat: {
      zksync: true,
    },
    zkSyncLocalSetup: {
      url: "http://localhost:3050",
      ethNetwork: "http://localhost:8545",
      zksync: true,
    },
    zkSyncTestNode: {
      url: "http://localhost:8011",
      ethNetwork: "http://localhost:8545",
      zksync: true,
    },
    zkSyncTestnet: {
      url: "https://testnet.era.zksync.dev",
      ethNetwork: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      zksync: true,
      verifyURL:
        "https://zksync2-testnet-explorer.zksync.dev/contract_verification",
    },
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000000,
      },
      metadata: {
        // do not include the metadata hash, since this is machine dependent
        // and we want all generated code to be deterministic
        // https://docs.soliditylang.org/en/v0.7.6/metadata.html
        bytecodeHash: "none",
      },
    },
  },
  paths: {
    sources: "./src",
  },
  zksolc: {
    version: "1.3.10",
    compilerSource: "binary",
    settings: {
      metadata: {
        // do not include the metadata hash, since this is machine dependent
        // and we want all generated code to be deterministic
        // https://docs.soliditylang.org/en/v0.7.6/metadata.html
        bytecodeHash: "none",
      },
    },
  },
  mocha: {
    timeout: 1000000000000,
  },
};
