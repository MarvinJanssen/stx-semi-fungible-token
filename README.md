# STX Semi-Fungible Token standard

This is a concept semi-fungible token standard and reference implementation for the Stacks blockchain. It also includes an example Wrapped SIP010 SFT contract that can wrap an arbitrary number of SIP010 tokens across different contracts. For more information on the standard and design of the SFT, check the [draft SIP document](sip013-semi-fungible-token-standard.md).

Semi-fungible tokens can be very useful in many different settings. Here are some examples:

**Art**

Art initiatives can use them to group an entire project into a single contract and mint multiple  series or collections in a single go. A single artwork can have multiple editions that can all be expressed by the same identifier. Artists can also use them to easily create a track-record of their work over time. Curation requires tracking a single contract instead of a new one per project.

**Games**

Games that have on-chain economies can leverage their flexibility to express their full in-game inventory in a single contract. For example, they may express their in-game currency with one token ID and a commodity with another. In-game item supplies can be managed in a more straightforward way and the game developers can introduce new item classes in a transparent manner.

## SFTs and post conditions

Post conditions are tricky because it is impossible to make assertions based on custom `print` events as of Stacks 2.0. Still, native events can be utilised to safeguard SFT actions in different ways. The reference SFT implementation in this repository defines a fungible token using `define-fungible-token` to allow for post conditions asserting the amount of tokens transferred. It enables the user to state "I will transfer exactly 50 semi-fungible tokens of contract A". I am still exploring options in which the user can also assert the type of token. There are definitely ways in which an NFT defined with `define-non-fungible-token` can be used.

Options I am considering:
- Mint and burn a native NFT with the provided token ID on every SFT action.
- Define a native NFT with a more complex token identifier and mint these to the contract when an event takes place. The challenge is creating something that is unique whilst still making it easy enough to create assertions for. For example:
  ```clarity
  (define-non-fungible-token sft-events {token-id: uint, amount: uint, sender: principal, recipient: principal, nonce: uint})

  (define-private (sft-event (token-id uint) (amount uint) (sender principal) (recipient principal))
  	(nft-mint? sft-events {token-id: token-id, amount: amount, sender: sender, recipient: recipient, nonce: (next-event-nonce)} (as-contract tx-sender))
  )
  ```
The second option makes it so we can also possibly do away with custom `print` events. A downside is that it creates an ever-growing NFT collection on the contract itself.
