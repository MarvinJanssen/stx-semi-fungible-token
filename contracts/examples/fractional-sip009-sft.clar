(impl-trait .sip013-semi-fungible-token-trait.sip013-semi-fungible-token-trait)

(define-constant contract-owner tx-sender)

(define-fungible-token fractional-sip009-sft)
(define-map token-balances {token-id: uint, owner: principal} uint)
(define-map token-supplies uint uint)
(define-map token-decimals uint uint)
(define-map nft-token-ids {asset-contract: principal, nft-token-id: uint} uint)
(define-map token-id-original-nft-id uint uint)
(define-map asset-contract-whitelist principal bool)
(define-data-var token-id-nonce uint u0)

(define-constant err-owner-only (err u100))
(define-constant err-not-whitelisted (err u101))
(define-constant err-unknown-token (err u102))
(define-constant err-insufficient-balance (err u1))
(define-constant err-invalid-sender (err u4))

(define-trait sip009-transferable-trait
	(
		(transfer (uint principal principal) (response bool uint))
	)
)

(define-private (set-balance (token-id uint) (balance uint) (owner principal))
	(map-set token-balances {token-id: token-id, owner: owner} balance)
)

(define-private (get-balance-uint (token-id uint) (who principal))
	(default-to u0 (map-get? token-balances {token-id: token-id, owner: who}))
)

(define-read-only (get-balance (token-id uint) (who principal))
	(ok (get-balance-uint token-id who))
)

(define-read-only (get-overall-balance (who principal))
	(ok (ft-get-balance fractional-sip009-sft who))
)

(define-read-only (get-total-supply (token-id uint))
	(ok (default-to u0 (map-get? token-supplies token-id)))
)

(define-read-only (get-overall-supply)
	(ok (ft-get-supply fractional-sip009-sft))
)

(define-read-only (get-decimals (token-id uint))
	(ok (default-to u0 (map-get? token-decimals token-id)))
)

(define-read-only (get-token-uri (token-id uint))
	(ok none)
)

(define-public (transfer (token-id uint) (amount uint) (sender principal) (recipient principal))
	(let
		(
			(sender-balance (get-balance-uint token-id sender))
		)
		(asserts! (is-eq tx-sender sender) err-invalid-sender)
		(asserts! (<= amount sender-balance) err-insufficient-balance)
		(try! (ft-transfer? fractional-sip009-sft amount sender recipient))
		(set-balance token-id (- sender-balance amount) sender)
		(set-balance token-id (+ (get-balance-uint token-id recipient) amount) recipient)
		(print {type: "sft_transfer_event", token-id: token-id, amount: amount, sender: sender, recipient: recipient})
		(ok true)
	)
)

(define-public (transfer-memo (token-id uint) (amount uint) (sender principal) (recipient principal) (memo (buff 34)))
	(begin
		(try! (transfer token-id amount sender recipient))
		(print memo)
		(ok true)
	)
)

(define-private (transfer-many-iter (item {token-id: uint, amount: uint, sender: principal, recipient: principal}) (previous-response (response bool uint)))
	(match previous-response prev-ok (transfer (get token-id item) (get amount item) (get sender item) (get recipient item)) prev-err previous-response)
)

(define-public (transfer-many (transfers (list 200 {token-id: uint, amount: uint, sender: principal, recipient: principal})))
	(fold transfer-many-iter transfers (ok true))
)

(define-private (transfer-many-memo-iter (item {token-id: uint, amount: uint, sender: principal, recipient: principal, memo: (buff 34)}) (previous-response (response bool uint)))
	(match previous-response prev-ok (transfer-memo (get token-id item) (get amount item) (get sender item) (get recipient item) (get memo item)) prev-err previous-response)
)

(define-public (transfer-many-memo (transfers (list 200 {token-id: uint, amount: uint, sender: principal, recipient: principal, memo: (buff 34)})))
	(fold transfer-many-memo-iter transfers (ok true))
)

;; Fractionalising and combining logic

(define-read-only (get-original-nft-id (asset-contract principal) (token-id uint))
	(map-get? token-id-original-nft-id token-id)
)

(define-read-only (get-asset-token-id (asset-contract principal) (nft-token-id uint))
	(map-get? nft-token-ids {asset-contract: asset-contract, nft-token-id: nft-token-id})
)

(define-public (get-or-create-asset-token-id (nft-token-id uint) (sip009-asset <sip009-transferable-trait>))
	(match (get-asset-token-id (contract-of sip009-asset) nft-token-id)
		token-id (ok token-id)
		(let
			(
				(token-id (+ (var-get token-id-nonce) u1))
			)
			(asserts! (is-whitelisted (contract-of sip009-asset)) err-not-whitelisted)
			(map-set nft-token-ids {asset-contract: (contract-of sip009-asset), nft-token-id: nft-token-id} token-id)
			(map-set token-id-original-nft-id token-id nft-token-id)
			(var-set token-id-nonce token-id)
			(ok token-id)
		)
	)
)

(define-public (fractionalise (nft-token-id uint) (amount uint) (sip009-asset <sip009-transferable-trait>))
	(let
		(
			(token-id (try! (get-or-create-asset-token-id nft-token-id sip009-asset)))
		)
		(try! (contract-call? sip009-asset transfer nft-token-id tx-sender (as-contract tx-sender)))
		(try! (ft-mint? fractional-sip009-sft amount tx-sender))
		(set-balance token-id amount tx-sender)
		(map-set token-supplies token-id amount)
		(print {type: "sft_mint_event", token-id: token-id, amount: amount, recipient: tx-sender})
		(ok token-id)
	)
)

(define-public (combine (nft-token-id uint) (recipient principal) (sip009-asset <sip009-transferable-trait>))
	(let
		(
			(token-id (unwrap! (get-asset-token-id (contract-of sip009-asset) nft-token-id) err-unknown-token))
			(token-supply (default-to u0 (map-get? token-supplies token-id)))
			(original-sender tx-sender)
		)
		(asserts! (is-eq (get-balance-uint token-id tx-sender) token-supply) err-insufficient-balance)
		(try! (ft-burn? fractional-sip009-sft token-supply original-sender))
		(try! (as-contract (contract-call? sip009-asset transfer nft-token-id  tx-sender original-sender)))
		(set-balance token-id u0 original-sender)
		(map-set token-supplies token-id u0)
		(print {type: "sft_burn_event", token-id: token-id, amount: token-supply, sender: original-sender})
		(ok token-id)
	)
)

(define-read-only (is-whitelisted (asset-contract principal))
	(default-to false (map-get? asset-contract-whitelist asset-contract))
)

(define-public (set-whitelisted (asset-contract principal) (whitelisted bool))
	(begin
		(asserts! (is-eq contract-owner tx-sender) err-owner-only)
		(ok (map-set asset-contract-whitelist asset-contract whitelisted))
	)
)
