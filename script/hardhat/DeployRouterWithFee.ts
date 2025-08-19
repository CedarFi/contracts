import fs from "fs";
import { network } from "hardhat";
import { join } from "path";
import Values from "../constants/values.json";
import { deploy } from "./utils/helpers";
import { RouterWithFee } from "../../artifacts/types";
import { writeFile } from "fs/promises";

interface CoreOutput {
  artProxy: string;
  distributor: string;
  factoryRegistry: string;
  forwarder: string;
  gaugeFactory: string;
  managedRewardsFactory: string;
  minter: string;
  poolFactory: string;
  router: string;
  CEDA: string;
  voter: string;
  votingEscrow: string;
  votingRewardsFactory: string;
  routerWithFee: string;
}

async function main() {
  const networkId = network.config.chainId as number;
  const outputDirectory = "script/constants/output";
  const outputFile = join(process.cwd(), outputDirectory, `CoreOutput-${String(networkId)}.json`);
  // const calleeFile = join(process.cwd(), outputDirectory, `CalleeOutput-${String(networkId)}.txt`);
  const CONSTANTS = Values[networkId as unknown as keyof typeof Values];

  const outputBuffer = fs.readFileSync(outputFile);
  const output: CoreOutput = JSON.parse(outputBuffer.toString());
  // const calleeBuffer = fs.readFileSync(calleeFile);
  // const callee = calleeBuffer.toString();

  const router = await deploy<RouterWithFee>(
    "RouterWithFee",
    undefined,
    output.forwarder,
    output.factoryRegistry,
    output.poolFactory,
    output.voter,
    CONSTANTS.WETH,
    CONSTANTS.team
  );

  output.routerWithFee = router.address;

  try {
    await writeFile(outputFile, JSON.stringify(output, null, 2));
  } catch (error) {
    console.error(`Error writing output file: ${error}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
