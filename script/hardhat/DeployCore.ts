import { deploy, deployLibrary } from "./utils/helpers";
import { createWriteStream, existsSync } from "fs";
import { writeFile } from "fs/promises";
import { join } from "path";
import { network } from "hardhat";
import { Libraries } from "hardhat/types";
import {
  ManagedRewardsFactory,
  VotingRewardsFactory,
  GaugeFactory,
  PoolFactory,
  FactoryRegistry,
  Pool,
  Minter,
  RewardsDistributor,
  CEDA,
  Voter,
  VeArtProxy,
  VotingEscrow,
  CEDAForwarder,
  RouterWithFee,
} from "../../artifacts/types";
import Values from "../constants/values.json";

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
  ceda: string;
  voter: string;
  votingEscrow: string;
  votingRewardsFactory: string;
}

async function main() {
  // ====== start _deploySetupBefore() ======
  const networkId: number = network.config.chainId as number;
  const MINT_VALUE = "1000000000000000000000000000";
  const CONSTANTS = Values[networkId as unknown as keyof typeof Values];
  const whitelistTokens = CONSTANTS.whitelistTokens;

  const ceda = await deploy<CEDA>("CEDA");
  await ceda.mint(CONSTANTS.team, MINT_VALUE);
  whitelistTokens.push(ceda.address);
  // ====== end _deploySetupBefore() ======

  // ====== start _coreSetup() ======

  // ====== start deployFactories() ======
  const implementation = await deploy<Pool>("Pool");

  const poolFactory = await deploy<PoolFactory>("PoolFactory", undefined, implementation.address);
  await poolFactory.setFee(true, 1);
  await poolFactory.setFee(false, 1);

  const votingRewardsFactory = await deploy<VotingRewardsFactory>("VotingRewardsFactory");

  const gaugeFactory = await deploy<GaugeFactory>("GaugeFactory");

  const managedRewardsFactory = await deploy<ManagedRewardsFactory>("ManagedRewardsFactory");

  const factoryRegistry = await deploy<FactoryRegistry>(
    "FactoryRegistry",
    undefined,
    poolFactory.address,
    votingRewardsFactory.address,
    gaugeFactory.address,
    managedRewardsFactory.address
  );
  // ====== end deployFactories() ======

  const forwarder = await deploy<CEDAForwarder>("CEDAForwarder");

  const balanceLogicLibrary = await deployLibrary("BalanceLogicLibrary");
  const delegationLogicLibrary = await deployLibrary("DelegationLogicLibrary");
  const libraries: Libraries = {
    BalanceLogicLibrary: balanceLogicLibrary.address,
    DelegationLogicLibrary: delegationLogicLibrary.address,
  };

  const escrow = await deploy<VotingEscrow>(
    "VotingEscrow",
    libraries,
    forwarder.address,
    ceda.address,
    factoryRegistry.address
  );

  const trig = await deployLibrary("Trig");
  const perlinNoise = await deployLibrary("PerlinNoise");
  const artLibraries: Libraries = {
    Trig: trig.address,
    PerlinNoise: perlinNoise.address,
  };

  const artProxy = await deploy<VeArtProxy>("VeArtProxy", artLibraries, escrow.address);
  await escrow.setArtProxy(artProxy.address);

  const distributor = await deploy<RewardsDistributor>("RewardsDistributor", undefined, escrow.address);

  const voter = await deploy<Voter>("Voter", undefined, forwarder.address, escrow.address, factoryRegistry.address);

  await escrow.setVoterAndDistributor(voter.address, distributor.address);

  // const router = await deploy<RouterWithFee>(
  //   "RouterWithFee",
  //   undefined,
  //   factoryRegistry.address,
  //   poolFactory.address,
  //   voter.address,
  //   CONSTANTS.WETH,
  //   CONSTANTS.team,
  //   {
  //     gasLimit: 900000,
  //   }
  // );

  const minter = await deploy<Minter>("Minter", undefined, voter.address, escrow.address, distributor.address);
  await distributor.setMinter(minter.address);
  await ceda.setMinter(minter.address);

  await voter.initialize(whitelistTokens, minter.address);
  // ====== end _coreSetup() ======

  // ====== start _deploySetupAfter() ======
  await escrow.setTeam(CONSTANTS.team);
  await minter.setTeam(CONSTANTS.team);
  await poolFactory.setPauser(CONSTANTS.team);
  await voter.setEmergencyCouncil(CONSTANTS.emergencyCouncil);
  await voter.setEpochGovernor(CONSTANTS.team);
  await voter.setGovernor(CONSTANTS.team);
  await factoryRegistry.transferOwnership(CONSTANTS.team);

  await poolFactory.setFeeManager(CONSTANTS.feeManager);
  await poolFactory.setVoter(voter.address);
  // ====== end _deploySetupAfter() ======

  const outputDirectory = "script/constants/output";
  const outputFile = join(process.cwd(), outputDirectory, `CoreOutput-${String(networkId)}.json`);

  const output: CoreOutput = {
    artProxy: artProxy.address,
    distributor: distributor.address,
    factoryRegistry: factoryRegistry.address,
    forwarder: forwarder.address,
    gaugeFactory: gaugeFactory.address,
    managedRewardsFactory: managedRewardsFactory.address,
    minter: minter.address,
    poolFactory: poolFactory.address,
    router: "",
    ceda: ceda.address,
    voter: voter.address,
    votingEscrow: escrow.address,
    votingRewardsFactory: votingRewardsFactory.address,
  };

  try {
    if (!existsSync(outputFile)) {
      const ws = createWriteStream(outputFile);
      ws.write(JSON.stringify(output, null, 2));
      ws.end();
    } else {
      await writeFile(outputFile, JSON.stringify(output, null, 2));
    }
  } catch (err) {
    console.error(`Error writing output file: ${err}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
