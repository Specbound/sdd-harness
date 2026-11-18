---
name: nft-standards
description: "Implement ERC-721 and ERC-1155 against OpenZeppelin Contracts v5 — metadata, ERC-2981 royalties, soulbound and dynamic tokens, gas-efficient minting. Use when writing or reviewing NFT contracts, or porting v4 code off removed APIs (Counters.sol, _beforeTokenTransfer, no-arg Ownable)."
risk: unknown
source: community
---

# NFT Standards

OpenZeppelin Contracts v5 removed several things every pre-2024 NFT tutorial uses. Code
copied from those tutorials does not compile against v5 — it fails at the constructor,
the hook override, and the `Counters` import. Fix the version question before anything
else.

## Use this skill when

- Writing or reviewing an ERC-721 / ERC-1155 contract
- Porting an NFT contract from OpenZeppelin v4 to v5
- Adding royalties, soulbound behavior, or on-chain metadata
- Reducing mint gas cost

## v4 → v5 migration

| v4 (removed in v5) | v5 |
|---|---|
| `import ".../utils/Counters.sol"` + `Counters.Counter` | plain `uint256 private _nextTokenId;` |
| `_beforeTokenTransfer` / `_afterTokenTransfer` | single `_update(to, tokenId, auth)` hook |
| `constructor() Ownable()` | `constructor() Ownable(msg.sender)` — owner is now an explicit arg |
| `_exists(tokenId)` | `_ownerOf(tokenId) != address(0)` |
| `ERC721._burn` override pairs | handled by `_update` |

`_update` fires on mint, burn, and transfer — `from == address(0)` is a mint,
`to == address(0)` is a burn. Collapsing three v4 hooks into one is the change that
breaks the most copied code.

## ERC-721

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721URIStorage, ERC721Enumerable, Ownable {
    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant MINT_PRICE = 0.08 ether;
    uint256 public constant MAX_PER_MINT = 20;

    uint256 private _nextTokenId = 1;
    string private _baseTokenURI;

    error InvalidQuantity();
    error ExceedsMaxSupply();
    error InsufficientPayment();

    constructor(string memory baseURI) ERC721("MyNFT", "MNFT") Ownable(msg.sender) {
        _baseTokenURI = baseURI;
    }

    function mint(uint256 quantity) external payable {
        if (quantity == 0 || quantity > MAX_PER_MINT) revert InvalidQuantity();
        if (_nextTokenId - 1 + quantity > MAX_SUPPLY) revert ExceedsMaxSupply();
        if (msg.value < MINT_PRICE * quantity) revert InsufficientPayment();

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, _nextTokenId++);
        }
    }

    function withdraw() external onlyOwner {
        (bool ok, ) = payable(owner()).call{value: address(this).balance}("");
        require(ok, "withdraw failed");
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // --- required multiple-inheritance overrides (v5) ---

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public view override(ERC721, ERC721URIStorage) returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC721URIStorage, ERC721Enumerable) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

Combining `ERC721URIStorage` and `ERC721Enumerable` is what forces the four overrides.
If you only need sequential IDs under one base URI, drop both extensions and
`_baseURI()` alone covers it — `ERC721Enumerable` adds meaningful gas to every transfer
to maintain its indexes, and off-chain indexers already provide enumeration.

Use `_safeMint` for EOAs and contracts that signal ERC-721 receipt; note it hands
control to the receiver, so keep state updates before the call (the loop above
increments before minting) and add a reentrancy guard if you add anything after it.

## ERC-1155

Use when tokens are semi-fungible (many copies of an edition) or when one contract
holds several token types. Batch transfers are the main win.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameItems is ERC1155, ERC1155Supply, Ownable {
    uint256 public constant SWORD = 1;
    uint256 public constant SHIELD = 2;

    constructor(string memory uri_) ERC1155(uri_) Ownable(msg.sender) {}

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        _mint(to, id, amount, "");
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts)
        external onlyOwner
    {
        _mintBatch(to, ids, amounts, "");
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }
}
```

The ERC-1155 URI convention is a single template containing `{id}` — clients substitute
a 64-character zero-padded lowercase hex ID. It is not interpolated on-chain.

## Metadata

Off-chain JSON is the norm; the marketplace-recognized shape is:

```json
{
  "name": "Item #1",
  "description": "...",
  "image": "ipfs://<CID>/1.png",
  "attributes": [
    {"trait_type": "Rarity", "value": "Legendary"},
    {"trait_type": "Level", "value": 42, "display_type": "number"}
  ]
}
```

- Pin to IPFS and reference `ipfs://<CID>/`, not an HTTP gateway URL — gateways go away
  and the token's art goes with them. Pin through a service that will keep it alive.
- Upload metadata **before** minting; a CID that 404s at mint is permanent if the base
  URI is immutable.
- Fully on-chain metadata (SVG + base64 `data:` URI from `tokenURI`) removes that
  dependency entirely, at a large gas cost. Worth it only for small generative art.

## Royalties (ERC-2981)

```solidity
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract MyNFT is ERC721, ERC2981, Ownable {
    constructor() ERC721("MyNFT", "MNFT") Ownable(msg.sender) {
        _setDefaultRoyalty(msg.sender, 500);   // 500 = 5%, basis points
    }

    function supportsInterface(bytes4 id)
        public view override(ERC721, ERC2981) returns (bool)
    {
        return super.supportsInterface(id);
    }
}
```

ERC-2981 only *advertises* a royalty — it does not enforce payment. Marketplaces choose
whether to honor it. Do not describe royalty income as guaranteed.

## Soulbound (non-transferable)

Override `_update` and reject anything that is not a mint or burn:

```solidity
error Soulbound();

function _update(address to, uint256 tokenId, address auth)
    internal override returns (address)
{
    address from = _ownerOf(tokenId);
    if (from != address(0) && to != address(0)) revert Soulbound();
    return super._update(to, tokenId, auth);
}
```

## Gas-efficient minting

- **ERC721A** (chiru-labs) makes batch mints near-constant cost by writing ownership
  once per batch instead of per token; the trade is more expensive transfers later. Worth
  it for large batch drops, not for 1-of-1s. It is a separate dependency and still
  follows v4-style conventions — do not mix its base with OZ v5's `_update` hook.
- **Merkle allowlists** beat an on-chain address mapping: store one root, verify a proof
  at mint.
- **Custom errors over `require` strings** (used above) — cheaper deploy and revert.
- `_nextTokenId++` on a `uint256` is already cheaper than the removed `Counters`
  wrapper, which only ever added a struct around the same increment.

## Pre-deploy checklist

- Mint supply cap enforced on the path that mints, including any owner-only mint
- Withdraw function present and tested — funds are otherwise locked forever
- `supportsInterface` overridden across every inherited base, or marketplaces misread
  the contract
- Metadata pinned and resolving before the first mint
- Reentrancy guard on anything with state changes after `_safeMint`
- Test against the OZ major version you actually pin — v4 and v5 contracts of the same
  shape differ in constructor and hooks
