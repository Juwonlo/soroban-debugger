import { runSmokeSuite } from './suites';

runSmokeSuite().catch((error) => {
  console.error(error);
  process.exit(1);
});
