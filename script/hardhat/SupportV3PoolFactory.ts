import fs from "fs";
import { network } from "hardhat";
import { join } from "path";
import { getContractAt } from "./utils/helpers";
import { FactoryRegistry } from "../../artifacts/types";

interface CoreOutput {
  factoryRegistry: string;
}

async function main() {
  const networkId = network.config.chainId as number;
  const outputDirectory = "script/constants/output";
  const outputFile = join(process.cwd(), outputDirectory, `CoreOutput-${String(networkId)}.json`);
  // const calleeFile = join(process.cwd(), outputDirectory, `CalleeOutput-${String(networkId)}.txt`);

  const outputBuffer = fs.readFileSync(outputFile);
  const output: CoreOutput = JSON.parse(outputBuffer.toString());
  // const calleeBuffer = fs.readFileSync(calleeFile);
  // const callee = calleeBuffer.toString();

  const registry = await getContractAt<FactoryRegistry>("FactoryRegistry", output.factoryRegistry);
  await registry.approve(
    "0x9dCfC5ff64216901BbFf6E9B7103c294c2f517F0",
    "0x34D0Fa959ad0B731742B61215427f5C8a03aBAdC",
    "0xd44B0500F3F5ED4e411f8dAAF9AA98DC4b1fd9Fe"
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
