;; Resource Processing Contract
;; Handles asteroid material processing and refinement

;; Constants
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_BATCH (err u301))
(define-constant ERR_INSUFFICIENT_MATERIALS (err u302))
(define-constant ERR_PROCESSING_ACTIVE (err u303))

;; Data Variables
(define-data-var next-batch-id uint u1)

;; Data Maps
(define-map raw-materials
  { operator: principal, material-type: (string-ascii 20) }
  { quantity: uint }
)

(define-map processing-batches
  { batch-id: uint }
  {
    operator: principal,
    material-type: (string-ascii 20),
    raw-quantity: uint,
    processed-quantity: uint,
    processing-start: uint,
    processing-duration: uint,
    status: (string-ascii 15)
  }
)

(define-map refined-materials
  { operator: principal, material-type: (string-ascii 20) }
  { quantity: uint }
)

;; Processing efficiency rates (percentage)
(define-map processing-rates
  { material-type: (string-ascii 20) }
  { efficiency: uint, duration-blocks: uint }
)

;; Contract References
(define-constant EXTRACTION_CONTRACT .extraction-protocol)

;; Initialize processing rates
(map-set processing-rates { material-type: "iron" } { efficiency: u85, duration-blocks: u100 })
(map-set processing-rates { material-type: "platinum" } { efficiency: u75, duration-blocks: u200 })
(map-set processing-rates { material-type: "rare-earth" } { efficiency: u60, duration-blocks: u300 })

;; Public Functions

;; Add raw materials from extraction
(define-public (add-raw-materials (material-type (string-ascii 20)) (quantity uint))
  (let
    (
      (current-quantity (default-to u0 (get quantity (map-get? raw-materials { operator: tx-sender, material-type: material-type }))))
    )
    (map-set raw-materials
      { operator: tx-sender, material-type: material-type }
      { quantity: (+ current-quantity quantity) }
    )

    (ok (+ current-quantity quantity))
  )
)

;; Start processing batch
(define-public (start-processing (material-type (string-ascii 20)) (quantity uint))
  (let
    (
      (batch-id (var-get next-batch-id))
      (current-raw (default-to u0 (get quantity (map-get? raw-materials { operator: tx-sender, material-type: material-type }))))
      (processing-rate (unwrap! (map-get? processing-rates { material-type: material-type }) ERR_INVALID_BATCH))
    )
    ;; Check sufficient raw materials
    (asserts! (>= current-raw quantity) ERR_INSUFFICIENT_MATERIALS)

    ;; Deduct raw materials
    (map-set raw-materials
      { operator: tx-sender, material-type: material-type }
      { quantity: (- current-raw quantity) }
    )

    ;; Create processing batch
    (map-set processing-batches
      { batch-id: batch-id }
      {
        operator: tx-sender,
        material-type: material-type,
        raw-quantity: quantity,
        processed-quantity: u0,
        processing-start: block-height,
        processing-duration: (get duration-blocks processing-rate),
        status: "processing"
      }
    )

    (var-set next-batch-id (+ batch-id u1))
    (ok batch-id)
  )
)

;; Complete processing batch
(define-public (complete-processing (batch-id uint))
  (let
    (
      (batch-data (unwrap! (map-get? processing-batches { batch-id: batch-id }) ERR_INVALID_BATCH))
      (processing-rate (unwrap! (map-get? processing-rates { material-type: (get material-type batch-data) }) ERR_INVALID_BATCH))
      (processed-quantity (/ (* (get raw-quantity batch-data) (get efficiency processing-rate)) u100))
      (current-refined (default-to u0 (get quantity (map-get? refined-materials { operator: (get operator batch-data), material-type: (get material-type batch-data) }))))
    )
    ;; Verify operator
    (asserts! (is-eq tx-sender (get operator batch-data)) ERR_UNAUTHORIZED)

    ;; Check if processing time has elapsed
    (asserts! (>= block-height (+ (get processing-start batch-data) (get processing-duration batch-data))) ERR_PROCESSING_ACTIVE)

    ;; Update batch status
    (map-set processing-batches
      { batch-id: batch-id }
      (merge batch-data {
        processed-quantity: processed-quantity,
        status: "completed"
      })
    )

    ;; Add refined materials
    (map-set refined-materials
      { operator: (get operator batch-data), material-type: (get material-type batch-data) }
      { quantity: (+ current-refined processed-quantity) }
    )

    (ok processed-quantity)
  )
)

;; Read-only functions
(define-read-only (get-raw-materials (operator principal) (material-type (string-ascii 20)))
  (map-get? raw-materials { operator: operator, material-type: material-type })
)

(define-read-only (get-refined-materials (operator principal) (material-type (string-ascii 20)))
  (map-get? refined-materials { operator: operator, material-type: material-type })
)

(define-read-only (get-batch-details (batch-id uint))
  (map-get? processing-batches { batch-id: batch-id })
)

(define-read-only (get-processing-rate (material-type (string-ascii 20)))
  (map-get? processing-rates { material-type: material-type })
)
