---
name: web3-testing
description: "Test Solidity contracts with Hardhat and Foundry: fixtures, fuzz and invariant tests, mainnet forking, gas and coverage checks."
risk: unknown
source: community
---

# Web3 Smart Contract Testing

Patterns for testing Solidity contracts with Hardhat (JS/TS) and Foundry (Solidity).

**This skill ships as `SKILL.md` only — there are no bundled reference, asset, or script
files. Everything below is meant to be read and inlined, not opened from a path.**

## Use when

- Writing or reviewing a Hardhat/Foundry test suite for Solidity contracts
- Setting up mainnet-fork tests against live protocol addresses
- Adding fuzz or invariant tests to catch edge cases unit tests miss
- Diagnosing gas regressions or coverage gaps in a contract repo

## Do not use when

- The task is contract *authoring* or auditing rather than testing — the failure modes
  and tooling differ; reach for a Solidity security skill instead
- The chain is non-EVM (Solana, Cosmos, Move) — none of this tooling applies
- The question is about frontend web3 (wagmi/viem/ethers in an app), not contract tests

## Version check — do this first

These examples assume **Hardhat 2 + `@nomicfoundation/hardhat-toolbox` v5+, which bundles
ethers v6**. Two traps:

- **ethers v5 → v6 renames break silently in tests.** `ethers.utils.parseEther` →
  `ethers.parseEther`; `contract.address` → `await contract.getAddress()`;
  `await Contract.deploy()` no longer waits — add `await c.waitForDeployment()`;
  `receipt.gasUsed` is a **bigint**, so compare against `50000n`, not `50000`.
- **Hardhat 3 renamed the toolbox packages** (`hardhat-toolbox-mocha-ethers` /
  `hardhat-toolbox-viem`) and switched the default runner. Check `package.json` before
  copying config; do not assume the plugin names below.

Verify with `npx hardhat --version` and the `ethers` entry in `package.json` before
writing the first test.

## Hardhat config

```javascript
// hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");   // includes ethers v6, chai matchers, coverage, gas reporter
require("@nomicfoundation/hardhat-verify");    // NOT @nomiclabs/hardhat-etherscan — that package is deprecated

module.exports = {
  solidity: {
    version: "0.8.28",
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  networks: {
    hardhat: {
      forking: {
        url: process.env.MAINNET_RPC_URL,
        blockNumber: 15000000,   // pin the block — an unpinned fork makes tests non-reproducible and defeats RPC caching
      },
    },
    sepolia: {                   // goerli is dead; sepolia/holesky are the live testnets
      url: process.env.SEPOLIA_RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
  gasReporter: { enabled: process.env.REPORT_GAS === "true", currency: "USD" },
  etherscan: { apiKey: process.env.ETHERSCAN_API_KEY },
};
```

## Hardhat: fixtures are the core pattern

`loadFixture` snapshots after the first run and reverts to that snapshot for every later
test. It is both faster and safer than `beforeEach` redeployment — state cannot leak
between tests.

```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Token", function () {
  async function deployTokenFixture() {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy();
    await token.waitForDeployment();        // v6: deploy() does not wait
    return { token, owner, addr1, addr2 };
  }

  it("assigns total supply to the owner", async function () {
    const { token, owner } = await loadFixture(deployTokenFixture);
    expect(await token.totalSupply()).to.equal(await token.balanceOf(owner.address));
  });

  it("transfers between accounts", async function () {
    const { token, owner, addr1 } = await loadFixture(deployTokenFixture);
    await expect(token.transfer(addr1.address, 50))
      .to.changeTokenBalances(token, [owner, addr1], [-50, 50]);
  });

  it("reverts when the sender is short", async function () {
    const { token, owner, addr1 } = await loadFixture(deployTokenFixture);
    // Destructure EVERY signer you reference. Referencing an undeclared `owner`
    // here throws ReferenceError, and the test still "passes" under a bare
    // `.to.be.reverted` assertion — a classic false green.
    await expect(token.connect(addr1).transfer(owner.address, 1))
      .to.be.revertedWithCustomError(token, "ERC20InsufficientBalance");
      // OpenZeppelin v5 uses custom errors. Pre-v5 string reverts need
      // .revertedWith("ERC20: transfer amount exceeds balance") instead.
  });

  it("emits Transfer", async function () {
    const { token, owner, addr1 } = await loadFixture(deployTokenFixture);
    await expect(token.transfer(addr1.address, 50))
      .to.emit(token, "Transfer").withArgs(owner.address, addr1.address, 50);
  });

  it("respects a time lock", async function () {
    const { token } = await loadFixture(deployTokenFixture);
    await time.increase(86400);              // advance one day; do not sleep
    // assert the time-gated path
  });

  it("stays under the gas budget", async function () {
    const { token, addr1 } = await loadFixture(deployTokenFixture);
    const receipt = await (await token.transfer(addr1.address, 100)).wait();
    expect(receipt.gasUsed).to.be.lessThan(50000n);   // bigint in ethers v6
  });
});
```

**Prefer `loadFixture` over manual `evm_snapshot`/`evm_revert`.** Hand-rolled snapshots are
still correct, but they are easy to leak across `describe` blocks and `loadFixture` already
does the same thing with less code.

## Hardhat: mainnet forking

```javascript
describe("fork", function () {
  let dai, router;

  before(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [{ forking: { jsonRpcUrl: process.env.MAINNET_RPC_URL, blockNumber: 15000000 } }],
    });
    dai = await ethers.getContractAt("IERC20", "0x6B175474E89094C44Da98b954EedeAC495271d0F");
    router = await ethers.getContractAt("IUniswapV2Router", "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D");
  });

  it("moves real DAI from a whale", async function () {
    const whale = "0x...";                  // pick a holder that is funded AT the pinned block
    await network.provider.request({ method: "hardhat_impersonateAccount", params: [whale] });
    await network.provider.request({ method: "hardhat_setBalance", params: [whale, "0x1000000000000000000"] });
    // ^ impersonation grants signing, NOT gas. Without setBalance the tx reverts
    //   with "insufficient funds" and the failure looks like a contract bug.
    const signer = await ethers.getSigner(whale);
    const [, addr1] = await ethers.getSigners();
    await dai.connect(signer).transfer(addr1.address, ethers.parseEther("1000"));
  });
});
```

## Foundry (forge)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Token.sol";

contract TokenTest is Test {
    Token token;
    address owner = address(1);
    address user1 = address(2);

    function setUp() public {
        vm.prank(owner);
        token = new Token();
    }

    function test_Transfer() public {
        vm.prank(owner);
        token.transfer(user1, 100);
        assertEq(token.balanceOf(user1), 100);
    }

    // Use vm.expectRevert, not the testFail* prefix — testFail* is deprecated in
    // forge-std and passes on ANY revert, including an unrelated one you did not mean
    // to trigger. expectRevert pins the exact reason.
    function test_RevertWhen_InsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", user1, 0, 100));
        token.transfer(owner, 100);
    }

    // Fuzzing: forge calls this ~256x with random inputs. vm.assume discards
    // invalid draws; too broad an assume silently starves the run — check the
    // "rejected" counter in the output.
    function testFuzz_Transfer(uint256 amount) public {
        vm.assume(amount > 0 && amount <= token.totalSupply());
        vm.prank(owner);
        token.transfer(user1, amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function test_Fork() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 15000000);
        address dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        assertEq(IERC20Metadata(dai).symbol(), "DAI");   // symbol() is on IERC20Metadata, not IERC20
    }
}
```

### Invariant tests — the thing unit tests cannot do

A fuzz test checks one function against random inputs. An **invariant** test checks a
property that must hold after *any* sequence of calls — this is where real protocol bugs
surface.

```solidity
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract TokenInvariants is StdInvariant, Test {
    Token token;

    function setUp() public {
        token = new Token();
        targetContract(address(token));   // restrict the random call surface
    }

    function invariant_TotalSupplyEqualsSumOfBalances() public view {
        assertEq(token.totalSupply(), token.balanceOf(address(this)) /* + tracked holders */);
    }
}
```

Tune depth/runs in `foundry.toml` under `[invariant]` — the defaults are shallow enough to
miss multi-step bugs.

### Useful cheatcodes

| Cheatcode | Effect |
|---|---|
| `vm.prank(a)` | next call only comes from `a`; `startPrank`/`stopPrank` for a span |
| `vm.deal(a, 10 ether)` | set ETH balance |
| `vm.warp(t)` / `vm.roll(n)` | set timestamp / block number |
| `vm.expectRevert(bytes)` | assert the next call reverts with that exact data |
| `vm.expectEmit(...)` | assert the next event matches |
| `vm.envString("KEY")` | read env (keeps RPC URLs out of the repo) |

## Coverage and gas

```bash
npx hardhat coverage              # Hardhat: istanbul-style report
forge coverage                    # Foundry equivalent
forge test --gas-report           # per-function gas table
forge snapshot --check            # fail CI if gas regressed vs .gas-snapshot
```

`forge snapshot --check` is the one that actually prevents gas regressions — a
`console.log` comparison in a test does not fail the build.

## Verification

```bash
npx hardhat verify --network mainnet CONTRACT_ADDRESS "arg1" "arg2"
forge verify-contract CONTRACT_ADDRESS src/Token.sol:Token --chain mainnet
```

Constructor args must match the deployed bytecode exactly, including types — a `uint256`
passed where the constructor takes `uint128` fails verification with an unhelpful error.

## CI

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { submodules: recursive }     # Foundry deps are git submodules
      - uses: actions/setup-node@v4
        with: { node-version: "20" }
      - uses: foundry-rs/foundry-toolchain@v1
      - run: npm ci
      - run: npx hardhat compile
      - run: npx hardhat test
      - run: forge test -vvv
      - run: forge snapshot --check
    env:
      MAINNET_RPC_URL: ${{ secrets.MAINNET_RPC_URL }}
```

Fork tests need an RPC secret in CI. Without it they either skip silently or fail on every
PR from a fork of the repo — decide which, and make it explicit.

## Checklist

- [ ] ethers major version confirmed against `package.json` before copying any snippet
- [ ] Fork block number pinned, not latest
- [ ] Every signer referenced in a test is destructured from the fixture
- [ ] Impersonated accounts given a balance via `hardhat_setBalance`
- [ ] Revert assertions name the specific error, never bare `.to.be.reverted`
- [ ] Fuzz tests checked for a high `rejected` count from over-broad `vm.assume`
- [ ] At least one invariant covering a supply/accounting property
- [ ] Access control and reentrancy paths have explicit negative tests
- [ ] `forge snapshot --check` wired into CI
