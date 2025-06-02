;; Mining Entity Verification Contract
;; Validates and manages asteroid mining operations

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_VERIFIED (err u102))
(define-constant ERR_INVALID_LICENSE (err u103))

;; Data Variables
(define-data-var next-entity-id uint u1)

;; Data Maps
(define-map mining-entities
  { entity-id: uint }
  {
    operator: principal,
    license-hash: (buff 32),
    verification-status: bool,
    registration-block: uint,
    expiry-block: uint
  }
)

(define-map entity-by-operator principal uint)

;; Public Functions

;; Register a new mining entity
(define-public (register-mining-entity (license-hash (buff 32)) (validity-blocks uint))
  (let
    (
      (entity-id (var-get next-entity-id))
      (current-block block-height)
    )
    (asserts! (is-none (map-get? entity-by-operator tx-sender)) ERR_ALREADY_VERIFIED)

    (map-set mining-entities
      { entity-id: entity-id }
      {
        operator: tx-sender,
        license-hash: license-hash,
        verification-status: false,
        registration-block: current-block,
        expiry-block: (+ current-block validity-blocks)
      }
    )

    (map-set entity-by-operator tx-sender entity-id)
    (var-set next-entity-id (+ entity-id u1))

    (ok entity-id)
  )
)

;; Verify a mining entity (only contract owner)
(define-public (verify-entity (entity-id uint))
  (let
    (
      (entity-data (unwrap! (map-get? mining-entities { entity-id: entity-id }) ERR_NOT_VERIFIED))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set mining-entities
      { entity-id: entity-id }
      (merge entity-data { verification-status: true })
    )

    (ok true)
  )
)

;; Check if entity is verified and not expired
(define-read-only (is-entity-verified (operator principal))
  (match (map-get? entity-by-operator operator)
    entity-id
      (match (map-get? mining-entities { entity-id: entity-id })
        entity-data
          (and
            (get verification-status entity-data)
            (< block-height (get expiry-block entity-data))
          )
        false
      )
    false
  )
)

;; Get entity details
(define-read-only (get-entity-details (entity-id uint))
  (map-get? mining-entities { entity-id: entity-id })
)
