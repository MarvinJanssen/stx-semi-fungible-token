;; clash of clans type game contract with multiple tokens as currencies 
;; and resources which can be upgraded by player using tokens 
(impl-trait .sipxxx-semi-fungible-token-trait.sipxxx-semi-fungible-token-trait)

(define-fungible-token clash-of-clans)
(define-map token-balances {token-id: uint, owner: principal} uint)
(define-map token-supplies uint uint)

(define-constant contract-owner tx-sender)
;; (define-constant sft .semi-fungible-token)

(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u1))
(define-constant err-invalid-sender (err u4))
(define-constant err-max-limit-reached (err u101))
(define-constant err-invalid-upgrade (err u102))
(define-constant err-player-already-exists (err u103))

;; economy as multiple token ids 
(define-constant gold u0)
(define-constant elixir u1)
(define-constant dark-elixir u2)
(define-constant heroes u3)

;; upgradable resource types 
(define-constant townhall u10)
(define-constant defenses u11)
(define-constant buildings u12)
(define-constant walls u13)
(define-constant troops u14)
(define-constant hero-levels u15)

;; costs map
(define-map upgrade-cost {resource: uint, level: uint} 
        {gold: uint, elixir: uint, dark-elixir: uint})

;; max supply for each token id
(define-map max-subtoken-supply uint uint) 

;; resource levels of a player
(define-map player-level {player: principal, resource: uint} uint) 

;; init economy max limits per player
(map-set max-subtoken-supply gold u7500000)
(map-set max-subtoken-supply elixir u7500000)
(map-set max-subtoken-supply dark-elixir u40000)
(map-set max-subtoken-supply heroes u4)

;; init upgrade costs for level 1 to level 2
(map-set upgrade-cost {resource: townhall, level: u2} 
        {gold: u5000, elixir: u5000, dark-elixir: u0})
(map-set upgrade-cost {resource: defenses, level: u2} 
        {gold: u1000, elixir: u1000, dark-elixir: u0})
(map-set upgrade-cost {resource: buildings, level: u2} 
        {gold: u0, elixir: u1000, dark-elixir: u0})
(map-set upgrade-cost {resource: walls, level: u2} 
        {gold: u100, elixir: u100, dark-elixir: u0})
(map-set upgrade-cost {resource: troops, level: u2} 
        {gold: u0, elixir: u2000, dark-elixir: u0})
(map-set upgrade-cost {resource: hero-levels, level: u2} 
        {gold: u200000, elixir: u200000, dark-elixir: u1000})

;; //////////////////////////////////////////////
;; Implementing sipxxx-semi-fungible-token-trait
(define-read-only (get-balance (token-id uint) (who principal))
	(ok (get-balance-or-default token-id who))
)

(define-read-only (get-overall-balance (who principal))
	(ok (ft-get-balance clash-of-clans who))
)

(define-read-only (get-total-supply (token-id uint))
	(ok (default-to u0 (map-get? token-supplies token-id)))
)

(define-read-only (get-overall-supply)
	(ok (ft-get-supply clash-of-clans))
)

(define-read-only (get-decimals (token-id uint))
	(ok u0)
)

(define-read-only (get-token-uri (token-id uint))
	(ok none)
)

(define-public (transfer (token-id uint) (amount uint) (sender principal) (recipient principal))
	(let
		(
			(sender-balance (get-balance-or-default token-id sender))
            (recipient-balance (get-balance-or-default token-id recipient))
		)
		(asserts! (is-eq tx-sender sender) err-invalid-sender)
		(asserts! (<= amount sender-balance) err-insufficient-balance)
		(try! (ft-transfer? clash-of-clans amount sender recipient))
		(set-balance token-id (- sender-balance amount) sender)
		(set-balance token-id (+ recipient-balance amount) recipient)
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

(define-public (transfer-many (transfers (list 200 {token-id: uint, amount: uint, sender: principal, recipient: principal})))
	(fold transfer-many-iter transfers (ok true))
)

(define-public (transfer-many-memo (transfers (list 200 {token-id: uint, amount: uint, sender: principal, recipient: principal, memo: (buff 34)})))
	(fold transfer-many-memo-iter transfers (ok true))
)
;; /////////////////////////////////////////

;; ////////////////////////////////////////
;; helper functions for sipxxx-semi-fungible-token-trait implementation
(define-private (set-balance (token-id uint) (balance uint) (owner principal))
	(map-set token-balances {token-id: token-id, owner: owner} balance)
)

(define-private (get-balance-or-default (token-id uint) (who principal))
	(default-to u0 (map-get? token-balances {token-id: token-id, owner: who}))
)

(define-private (transfer-many-memo-iter (item {token-id: uint, amount: uint, sender: principal, recipient: principal, memo: (buff 34)}) (previous-response (response bool uint)))
	(match previous-response prev-ok (transfer-memo (get token-id item) (get amount item) (get sender item) (get recipient item) (get memo item)) prev-err previous-response)
)

(define-private (transfer-many-iter (item {token-id: uint, amount: uint, sender: principal, recipient: principal}) (previous-response (response bool uint)))
	(match previous-response prev-ok (transfer (get token-id item) (get amount item) (get sender item) (get recipient item)) prev-err previous-response)
)

(define-private (mint (token-id uint) (amount uint) (recipient principal))
	(begin
		(asserts! (is-eq tx-sender contract-owner) err-owner-only)
		(try! (ft-mint? clash-of-clans amount recipient))
		(set-balance token-id (+ (get-balance-or-default token-id recipient) amount) recipient)
		(map-set token-supplies token-id (+ (unwrap-panic (get-total-supply token-id)) amount))
		(print {type: "coc_mint", token-id: token-id, amount: amount, recipient: recipient})
		(ok true)
	)
)

(define-private (burn (token-id uint) (amount uint) (sender principal)) 
	(let 
		(
			(sender-balance (get-balance-or-default token-id sender))
		)
		(asserts! (is-eq tx-sender sender) err-invalid-sender)
		(asserts! (>= sender-balance amount) err-insufficient-balance)
		(try! (ft-burn? clash-of-clans amount sender))
		(set-balance token-id (- sender-balance amount) sender)
		(map-set token-supplies token-id (- (unwrap-panic (get-total-supply token-id)) amount))
		(print {type: "coc_burn", token-id: token-id, amount: amount, sender: sender})
		(ok true)
	)
)
;; //////////////////////////////////////

(define-public (set-subtoken-total-supply (token-id uint) (supply uint)) 
	(begin
		(asserts! (is-eq tx-sender contract-owner) err-owner-only)
		(ok (map-set max-subtoken-supply token-id supply))
	)
)

(define-read-only (get-subtoken-total-supply (token-id uint)) 
	(default-to u0 (map-get? max-subtoken-supply token-id))
)

(define-public (set-upgrade-cost (resource uint) (level uint) (g uint) (e uint) (de uint)) 
	(begin
		(asserts! (is-eq tx-sender contract-owner) err-owner-only)
		(ok (map-set upgrade-cost {resource: resource, level: level} 
            {gold: g, elixir: e, dark-elixir: de}))
	)
)

(define-read-only (get-upgrade-cost (resource uint) (level uint)) 
	(default-to {gold: u0, elixir: u0, dark-elixir: u0} 
        (map-get? upgrade-cost {resource: resource, level: level}))
)

(define-public (add-player (player principal)) 
    (begin 
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? player-level {player: player, resource: townhall})) err-player-already-exists)
        (map-set player-level {player: player, resource: townhall} u1)
        (map-set player-level {player: player, resource: defenses} u1)
        (map-set player-level {player: player, resource: buildings} u1)
        (map-set player-level {player: player, resource: walls} u1)
        (map-set player-level {player: player, resource: troops} u1)
        (map-set player-level {player: player, resource: hero-levels} u0)
        (ok true)
    )
)

(define-read-only (get-player-level (player principal) (resource uint)) 
    (default-to u0 (map-get? player-level {player: player, resource: resource}))
)

(define-read-only (get-player-info (player principal)) 
    (let 
        (
            (th (get-player-level player townhall))
            (defense-levels (get-player-level player defenses))
            (building-levels (get-player-level player buildings))
            (wall-levels (get-player-level player walls))
            (troop-levels (get-player-level player troops))
            (warriors (get-player-level player hero-levels))
        ) 
        {townhall: th, defenses: defense-levels, buildings: building-levels, walls: wall-levels, troops: troop-levels, heroes: warriors}
    )
)

;; TODO: payment using stx / SIP-010 like in wrapped tokens ?
(define-public (purchase-token (token-id uint) (amount uint)) (ok true))

;; players can buy using fiat or earn by game play 
;; after a purchase or earn, this function will be called by owner principal 
(define-public (send-tokens (token-id uint) (amount uint) (recipient principal)) 
    (let 
        (
            (subtoken-supply (get-subtoken-total-supply token-id))
            (curr-balance (unwrap-panic (get-balance token-id recipient)))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= (+ amount curr-balance) subtoken-supply) err-max-limit-reached)
        (try! (mint token-id amount recipient))
        (ok true)
    )
)

(define-private (spend (token-id uint) (amount uint)) 
    (if (> amount u0) (burn token-id amount tx-sender) (ok true))
)

(define-public (upgrade (resource uint) (to-level uint)) 
    (let
        (
            (gold-bal (unwrap-panic (get-balance gold tx-sender)))
            (elixir-bal (unwrap-panic (get-balance elixir tx-sender)))
            (dark-elixir-bal (unwrap-panic (get-balance dark-elixir tx-sender)))
            (cost (get-upgrade-cost resource to-level))
            (req-gold (get gold cost))
            (req-elixir (get elixir cost))
            (req-dark-elixir (get dark-elixir cost))
            (curr-level (get-player-level tx-sender resource))
        )
        (asserts! (>= to-level u2) err-invalid-upgrade)
        (asserts! (is-eq (+ curr-level u1) to-level) err-invalid-upgrade)
        (asserts! (> (+ req-gold req-elixir req-dark-elixir) u0) err-invalid-upgrade)
        (asserts! (and (>= gold-bal req-gold) (>= elixir-bal req-elixir) (>= dark-elixir-bal req-dark-elixir)) err-insufficient-balance)
        
        (map-set player-level {player: tx-sender, resource: resource} to-level)

        (try! (spend gold req-gold))
        (try! (spend elixir req-elixir))
        (try! (spend dark-elixir req-dark-elixir))

        (ok true)
    )
)