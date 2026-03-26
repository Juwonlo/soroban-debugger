import { runDapE2ESuite, runSmokeSuite } from './suites';

async function main(): Promise<void> {
  await runSmokeSuite();
  await runDapE2ESuite();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
