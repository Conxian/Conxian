import { initSimnet } from "@stacks/clarinet-sdk";

async function main() {
  try {
    const simnet = await initSimnet();
    console.log("Simnet initialized successfully.");
    // This is a proxy for `clarinet check`, as initSimnet will fail if there are contract errors.
  } catch (e) {
    console.error("Error initializing simnet:", e);
    process.exit(1);
  }
}

main();
