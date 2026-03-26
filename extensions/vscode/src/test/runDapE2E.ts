import { runDapE2ESuite } from './suites';

runDapE2ESuite().catch((error) => {
  console.error(error);
  process.exit(1);
});
