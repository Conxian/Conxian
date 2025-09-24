# Clarity SDK Capabilities and Gaps

This document contains notes on the capabilities and gaps of the Clarity language and SDK, based on the experience of implementing the founder token reallocation feature.

## Capabilities

- **Strongly Typed and Decidable:** Clarity's design as a non-Turing complete language makes it very secure and predictable. The cost of execution can be determined statically, which prevents entire classes of bugs and attacks.
- **SIP-010 Standard:** The SIP-010 standard for fungible tokens is well-defined and easy to implement.
- **Contract-to-Contract Calls:** Clarity allows for easy and secure calls between contracts, which is essential for building complex systems.
- **Rich Set of Built-in Functions:** Clarity provides a good set of built-in functions for common operations, such as list manipulation, arithmetic, and cryptography.

## Gaps and Limitations

- **No On-chain Recursion:** Clarity does not support recursion, which makes it difficult to implement certain types of logic, such as iterating over a list of unknown size. The `founder-search` and `count-votes` functions in the initial implementation of the `governance-metrics.clar` contract failed because of this limitation. The workaround was to use a non-recursive design with aggregated data, but this adds complexity to the system.
- **No Loops:** The lack of loops makes it hard to iterate over data structures. This limitation is closely related to the lack of recursion. While `fold` can be used in some cases, it's not a general-purpose solution.
- **No On-chain Automation:** Clarity does not have a built-in mechanism for on-chain automation, such as cron jobs. This means that any function that needs to be called periodically, like the `check-and-reallocate-founder-tokens` function, must be triggered by an external process (a keeper). This adds a dependency on an off-chain component, which can be a single point of failure if not designed carefully.
- **Limited Tooling:** The `clarinet` tool provided with the project did not have a `test` subcommand, which was unexpected. The tests had to be run using a script defined in `package.json`. While this works, it would be better if the standard tooling supported all the necessary development workflows.

## Recommendations

- **Improve Clarity Language:** Adding support for bounded loops or a more powerful form of iteration would make it much easier to write complex smart contracts.
- **Provide On-chain Automation:** A built-in mechanism for on-chain automation would be a very valuable addition to the Stacks blockchain.
- **Improve Tooling:** The `clarinet` tool should be improved to provide a more consistent and user-friendly experience for developers.
