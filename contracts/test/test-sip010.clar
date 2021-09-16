(impl-trait .sip010-ft-trait.sip010-ft-trait)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))

(define-fungible-token test-sip010)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
	(begin
		(asserts! (is-eq tx-sender sender) err-owner-only)
		(try! (ft-transfer? test-sip010 amount sender recipient))
		(match memo to-print (print to-print) 0x)
		(ok true)
	)
)

(define-read-only (get-name)
	(ok "Clarity Coin")
)

(define-read-only (get-symbol)
	(ok "CC")
)

(define-read-only (get-decimals)
	(ok u0)
)

(define-read-only (get-balance (who principal))
	(ok (ft-get-balance test-sip010 who))
)

(define-read-only (get-total-supply)
	(ok (ft-get-supply test-sip010))
)

(define-read-only (get-token-uri)
	(ok none)
)

(define-public (mint (amount uint) (recipient principal))
	(ft-mint? test-sip010 amount recipient)
)