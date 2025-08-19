import fs from "fs";
import { network } from "hardhat";
import { join } from "path";
import { getContractAt } from "./utils/helpers";
import { RouterWithFee } from "../../artifacts/types";

interface CoreOutput {
  routerWithFee: string;
}

async function main() {
  const networkId = network.config.chainId as number;
  const outputDirectory = "script/constants/output";
  const outputFile = join(process.cwd(), outputDirectory, `CoreOutput-${String(networkId)}.json`);
  const calleeFile = join(process.cwd(), outputDirectory, `CalleeOutput-${String(networkId)}.txt`);

  const outputBuffer = fs.readFileSync(outputFile);
  const output: CoreOutput = JSON.parse(outputBuffer.toString());
  const calleeBuffer = fs.readFileSync(calleeFile);
  const callee = calleeBuffer.toString();

  const router = await getContractAt<RouterWithFee>("RouterWithFee", output.routerWithFee);
  await router.setCallee(callee);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
