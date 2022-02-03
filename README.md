# STX Semi-Fungible Token standard

This is a concept semi-fungible token standard and reference implementation for the Stacks blockchain. It also includes an example Wrapped SIP010 SFT contract that can wrap an arbitrary number of SIP010 tokens across different contracts. For more information on the standard and design of the SFT, check the [draft SIP document](sip013-semi-fungible-token-standard.md).

Semi-fungible tokens can be very useful in many different settings. Here are some examples:

**Art**

Art initiatives can use them to group an entire project into a single contract and mint multiple  series or collections in a single go. A single artwork can have multiple editions that can all be expressed by the same identifier. Artists can also use them to easily create a track-record of their work over time. Curation requires tracking a single contract instead of a new one per project.

**Games**

Games that have on-chain economies can leverage their flexibility to express their full in-game inventory in a single contract. For example, they may express their in-game currency with one token ID and a commodity with another. In-game item supplies can be managed in a more straightforward way and the game developers can introduce new item classes in a transparent manner.

## SFTs and post conditions

Post conditions are tricky because it is impossible to make assertions based on custom `print` events as of Stacks 2.0. Still, native events can be utilised to safeguard SFT actions. The reference SFT implementation in this repository utilises both `define-fungible-token` and `define-non-fungible-token`. Doing so allows for post conditions asserting both amount of tokens as well as the token ID transferred. Users can thus effectively safeguard their SFTs and express "I will transfer exactly *N* semi-fungible tokens with ID *I* of contract *X*" in post conditions.

The way it works is pretty interesting. First, both a fungible and non-fungible token are defined.

```clojure
(define-fungible-token semi-fungible-token)
(define-non-fungible-token semi-fungible-token-id {token-id: uint, owner: principal})
```

Notice how the non-fungible token has a complex asset identifier type definition of `{token-id: uint, owner: principal}`. Although uncommon, it is a perfectly legitimate thing to do. Remember, non-fungible tokens are represented by a unique identifier. The identifier type is something that can be played with. The reason for not simply using a `uint` is because it would make it impossible for multiple principals to a token with the same SFT ID. For SFTs, a token type *T* can have a total supply of *S*, spread out over *N* principals. Using an asset identifier type like the one above allows the contract to hand out multiple NFTs with the "same" token ID. The principal is merely used as a differentiator to make it unique per owner.

With these tokens set up, the contract will do two specific things that can be checked by post conditions when a semi-fungible token is transferred:

1. It transfers the specified amount of `semi-fungible-token` fungible tokens from the sender to the recipient.
2. It performs a burn-and-mint operation for the `semi-fungible-token-id` NFT for both the sender and the recipient.

Since the fungible token transfer and the burn of the NFT both impact the `tx-sender`, post conditions will be required if the transaction is set to `DENY` mode.

