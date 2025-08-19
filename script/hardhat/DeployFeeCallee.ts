import { deploy } from "./utils/helpers";
import { createWriteStream, existsSync, readFileSync } from "fs";
import { writeFile } from "fs/promises";
import { join } from "path";
import { network } from "hardhat";
import { CedarFeeCallee } from "../../artifacts/types";
import Values from "../constants/values.json";

interface CoreOutput {
  router: string;
}

async function main() {
  // ====== start _deploySetupBefore() ======
  const networkId: number = network.config.chainId as number;
  const CONSTANTS = Values[networkId as unknown as keyof typeof Values];
  const outputDirectory = "script/constants/output";
  const coreOutput = join(process.cwd(), outputDirectory, `CoreOutput-${String(networkId)}.json`);
  const outputFile = join(process.cwd(), outputDirectory, `CalleeOutput-${String(networkId)}.txt`);
  const outputBuffer = readFileSync(coreOutput);
  const output: CoreOutput = JSON.parse(outputBuffer.toString());
  const callee = await deploy<CedarFeeCallee>(
    "CedarFeeCallee",
    undefined,
    CONSTANTS.team,
    CONSTANTS.team,
    CONSTANTS.WETH,
    output.router
  );

  try {
    if (!existsSync(outputFile)) {
      const ws = createWriteStream(outputFile);
      ws.write(callee.address);
      ws.end();
    } else {
      await writeFile(outputFile, callee.address);
    }
  } catch (err) {
    console.error(`Error writing output file: ${err}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
