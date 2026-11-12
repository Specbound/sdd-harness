---
name: defi-protocol-templates
description: "Starting points and audit checklists for DeFi contracts — staking rewards, constant-product AMMs, on-chain governance, and flash loans. Use when writing or reviewing Solidity for any of those four, or when deciding whether to fork a battle-tested protocol instead of writing one."
risk: unknown
source: community
---

# DeFi Protocol Templates

Skeletons and audit checklists for four protocol shapes: staking rewards,
constant-product AMM, governance, flash loans. Each defence below is annotated with the
attack it stops.

**This skill ships as `SKILL.md` only — no bundled reference, asset, or script files.**

## Use when

- Writing or reviewing a staking, AMM, governance, or flash-loan contract
- Auditing one of the above for the standard loss-of-funds patterns
- Deciding between forking an audited protocol and writing from scratch

## Prefer forking over writing

None of this is production-ready and nothing short of an audit makes it so. Each shape
has an implementation that has held real money for years:

| Shape | Fork instead | Why |
|---|---|---|
| Staking | Synthetix `StakingRewards` | The math below is theirs, plus reward solvency |
| AMM | Uniswap V2 `UniswapV2Pair` | Fee-on-transfer handling, TWAP oracle, liquidity lock |
| Governance | OZ `Governor` + `TimelockController` | Quorum, voting delay, timelock, execution |
| Flash loan | OZ `ERC20FlashMint` / ERC-3156 | A standard borrowers already implement |

Write your own only for behaviour those cannot express.

## Version check — before writing a line

Code below targets **OpenZeppelin v5**. v4 code (most DeFi tutorials) does not compile
against it:

| v4 | v5 |
|---|---|
| `security/ReentrancyGuard.sol` | `utils/ReentrancyGuard.sol` |
| `Ownable()` | `Ownable(initialOwner)` — arg required |
| `_before/_afterTokenTransfer` | one `_update(from, to, value)` hook |
| `ERC20Votes` includes `ERC20Permit` | inherit `ERC20Permit`, override `nonces` |
| `_mint`/`_burn` overrides for votes | not needed, `_update` covers both |

```bash
npm ls @openzeppelin/contracts   # check the major before copying anything
```

Pin the compiler exactly (`pragma solidity 0.8.26;`, not `^0.8.0`) or your verified and
local bytecode drift. Since 0.8.20 the default EVM target emits `PUSH0`; deploying to a
pre-Shanghai chain needs `evmVersion: "paris"` or it reverts uninformatively.

## Staking rewards

Synthetix-style accounting. `updateReward` settles earned rewards *before* any balance
changes, so rate and balances can both move without iterating over stakers.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StakingRewards is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    uint256 public periodFinish;      // accrual stops here
    uint256 public rewardRate;        // per second, set by notifyRewardAmount
    uint256 public rewardsDuration = 7 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    error SameToken(); error ZeroAmount(); error RewardTooHigh();

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _staking, address _rewards, address owner_) Ownable(owner_) {
        // Same token both sides lets getReward() pay out other users' principal.
        if (_staking == _rewards) revert SameToken();
        stakingToken = IERC20(_staking);
        rewardsToken = IERC20(_rewards);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // Caps accrual at periodFinish. Without it rewards accrue forever, the contract
    // promises tokens it does not hold, early claimers drain it and everyone after
    // them reverts. This one line is the solvency guarantee.
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) return rewardPerTokenStored;
        return rewardPerTokenStored
            + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalSupply;
    }

    function earned(address a) public view returns (uint256) {
        return (balanceOf[a] * (rewardPerToken() - userRewardPerTokenPaid[a])) / 1e18 + rewards[a];
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        totalSupply += amount;
        balanceOf[msg.sender] += amount;
        // safeTransferFrom, not transferFrom: USDT returns no bool, some tokens
        // return false instead of reverting — a bare call credits the balance above
        // even when no transfer happened.
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;                 // state before interaction
            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    // Fund the contract first. The balance check stops an owner announcing rewards
    // the contract cannot pay.
    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 leftover = (periodFinish - block.timestamp) * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }
        if (rewardRate > rewardsToken.balanceOf(address(this)) / rewardsDuration) {
            revert RewardTooHigh();
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
    }

    function exit() external { withdraw(balanceOf[msg.sender]); getReward(); }
}
```

**Audit checklist:** `lastTimeRewardApplicable()` present, or rewards are unbounded and
insolvent · `notifyRewardAmount` checks the real reward-token balance · `SafeERC20`
everywhere · staking token ≠ reward token · rewards zeroed before transfer
(`nonReentrant` is the backstop, not the design) · rebasing or fee-on-transfer staking
tokens break `balanceOf` accounting — reject them or credit the measured delta, never
the `amount` argument.

## Constant-product AMM

`x * y >= k` with a 0.3% fee. Three things kill naive AMMs and all three are missing
from most tutorial code.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract ConstantProductAMM is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token0;
    IERC20 public immutable token1;
    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    // Burned on first mint so totalSupply can never return to 0. Without it the first
    // depositor mints 1 wei of shares, donates a large amount directly to the
    // contract, and every later deposit rounds to 0 shares — the inflation
    // (first-depositor) attack. Uniswap V2 burns exactly this.
    uint256 private constant MINIMUM_LIQUIDITY = 1000;

    error Expired(); error Slippage(); error InvalidToken(); error NoLiquidity();

    event Swap(address indexed trader, address tokenIn, uint256 amountIn, uint256 amountOut);

    // Without a deadline a validator can hold your tx and execute it later at a
    // price that suits them.
    modifier ensure(uint256 deadline) {
        if (block.timestamp > deadline) revert Expired();
        _;
    }

    constructor(address _t0, address _t1) { token0 = IERC20(_t0); token1 = IERC20(_t1); }

    function addLiquidity(uint256 amount0, uint256 amount1, uint256 minShares, uint256 deadline)
        external nonReentrant ensure(deadline) returns (uint256 shares)
    {
        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        if (totalSupply == 0) {
            shares = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            totalSupply += MINIMUM_LIQUIDITY;        // locked forever, minted to nobody
        } else {
            shares = Math.min((amount0 * totalSupply) / reserve0,
                              (amount1 * totalSupply) / reserve1);
        }
        if (shares == 0 || shares < minShares) revert Slippage();

        balanceOf[msg.sender] += shares;
        totalSupply += shares;
        _update();
    }

    function removeLiquidity(uint256 shares, uint256 min0, uint256 min1, uint256 deadline)
        external nonReentrant ensure(deadline) returns (uint256 amount0, uint256 amount1)
    {
        amount0 = (shares * reserve0) / totalSupply;
        amount1 = (shares * reserve1) / totalSupply;
        if (amount0 < min0 || amount1 < min1) revert Slippage();

        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;
        token0.safeTransfer(msg.sender, amount0);
        token1.safeTransfer(msg.sender, amount1);
        _update();
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, uint256 deadline)
        external nonReentrant ensure(deadline) returns (uint256 amountOut)
    {
        bool isToken0 = tokenIn == address(token0);
        if (!isToken0 && tokenIn != address(token1)) revert InvalidToken();

        (IERC20 tokenIn_, IERC20 tokenOut, uint256 resIn, uint256 resOut) = isToken0
            ? (token0, token1, reserve0, reserve1)
            : (token1, token0, reserve1, reserve0);

        tokenIn_.safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 amountInWithFee = (amountIn * 997) / 1000;          // 0.3%
        amountOut = (resOut * amountInWithFee) / (resIn + amountInWithFee);

        // The most important line in the contract. Without minAmountOut every swap is
        // free money for a sandwich bot: front-run to move the price, let your swap
        // fill worse, back-run to take the difference.
        if (amountOut < minAmountOut) revert Slippage();
        if (amountOut >= resOut) revert NoLiquidity();

        tokenOut.safeTransfer(msg.sender, amountOut);
        _update();
        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    // Reserves sync from real balances AFTER transfers. Reading balanceOf mid-swap
    // would let anyone shift the price by donating tokens to the contract.
    function _update() private {
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));
    }
}
```

**Audit checklist:** `minAmountOut` *and* `deadline` on every state-changing entry
point · `MINIMUM_LIQUIDITY` burned on first mint · reserves synced after transfers,
never read live mid-calculation · this contract is wrong for fee-on-transfer and
rebasing tokens — credit the measured delta or exclude them at the factory · spot price
from `reserve0/reserve1` is **not an oracle**; anything pricing collateral off pool spot
reserves is one flash loan from insolvency, so use a TWAP with a meaningful window or
Chainlink.

## Governance

Do not hand-roll. A hand-rolled Governor misses four things that each individually lose
the treasury:

1. **Quorum** — without it, one vote for and zero against passes.
2. **Voting delay** before the snapshot — without it an attacker borrows or buys tokens,
   proposes, and votes before anyone reacts.
3. **Timelock** on execution — without it a passed malicious proposal executes instantly
   and nobody can exit. This is what makes a governance attack survivable.
4. **Actual execution** — a Governor that emits `ProposalExecuted` but carries no call
   data governs nothing.

OZ `Governor` has all four. Token side, v5 syntax:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes {
    constructor(address treasury)
        ERC20("Governance Token", "GOV") ERC20Permit("Governance Token")
    {
        _mint(treasury, 1_000_000e18);
    }

    function _update(address from, address to, uint256 value)
        internal override(ERC20, ERC20Votes) { super._update(from, to, value); }

    function nonces(address owner)
        public view override(ERC20Permit, Nonces) returns (uint256) { return super.nonces(owner); }
}
```

Holders have **zero voting power until they call `delegate()`**, including to
themselves. Every governance launch hits this — budget for the support load.

Wire the Governor with `GovernorSettings`, `GovernorVotes`,
`GovernorVotesQuorumFraction`, `GovernorCountingSimple` and `GovernorTimelockControl`,
then transfer ownership of every privileged contract to the `TimelockController` — not
to the Governor, never to an EOA. Generate the scaffold from the OpenZeppelin Contracts
Wizard rather than a blog post; the wizard tracks the current major version.

## Flash loans

Implement **ERC-3156** rather than a bespoke callback: borrowers already have the
interface, and the standard pins down what bespoke providers get wrong — who moves the
tokens back.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract FlashLender is IERC3156FlashLender, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    uint256 private constant FEE_BPS = 9;            // 0.09%
    IERC20 public immutable token;

    error UnsupportedToken(); error CallbackFailed(); error NotRepaid();

    constructor(address _token) { token = IERC20(_token); }

    function maxFlashLoan(address t) external view returns (uint256) {
        return t == address(token) ? token.balanceOf(address(this)) : 0;
    }

    function flashFee(address t, uint256 amount) public view returns (uint256) {
        if (t != address(token)) revert UnsupportedToken();
        return (amount * FEE_BPS) / 10_000;
    }

    // nonReentrant is load-bearing: without it the borrower re-enters flashLoan from
    // inside onFlashLoan and borrows the same liquidity twice — the inner call reads
    // an already-reduced balance, so one repayment satisfies both checks.
    function flashLoan(IERC3156FlashBorrower receiver, address t, uint256 amount, bytes calldata data)
        external nonReentrant returns (bool)
    {
        if (t != address(token)) revert UnsupportedToken();
        uint256 fee = flashFee(t, amount);
        uint256 balanceBefore = token.balanceOf(address(this));

        token.safeTransfer(address(receiver), amount);
        if (receiver.onFlashLoan(msg.sender, t, amount, fee, data) != CALLBACK_SUCCESS) {
            revert CallbackFailed();
        }
        // ERC-3156: the borrower approves and the LENDER pulls. Checking the balance
        // alone is the classic broken template — the borrower approves, returns true,
        // and the loan is never actually repaid.
        token.safeTransferFrom(address(receiver), address(this), amount + fee);
        if (token.balanceOf(address(this)) < balanceBefore + fee) revert NotRepaid();
        return true;
    }
}
```

Borrower side: `onFlashLoan` must `approve(msg.sender, amount + fee)` **and** return
`CALLBACK_SUCCESS`, and must verify `msg.sender` is the expected lender — otherwise
anyone can call it directly and drain whatever it approves.

If you only need to lend your own token, OZ `ERC20FlashMint` mints and burns instead of
holding inventory, removing the liquidity check entirely.

## Before any mainnet deploy

- [ ] Audit, then a bug bounty — in that order, neither instead of the other
- [ ] Invariant and fuzz tests (`StdInvariant`, `forge test --fuzz-runs`); unit tests do
      not find the arithmetic edges that drain pools
- [ ] Fork tests against real addresses, including a fee-on-transfer token and USDT
- [ ] Every privileged role on a multisig behind a timelock, never an EOA
- [ ] Pause path tested from the account that would really use it
- [ ] Slither plus a symbolic or formal pass over the arithmetic
- [ ] Testnet, then mainnet with a value cap raised over weeks
- [ ] Checks-Effects-Interactions throughout; pull payments, never a loop of transfers
      over a user-controlled array
