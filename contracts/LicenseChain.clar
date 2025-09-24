;; LicenseChain - Digital Asset Licensing System
;; Version: 1.0.0
;; Manage digital asset licenses with creator validation

(define-map digital-licenses uint {
  creator: principal,
  asset-title: (string-utf8 64),
  license-terms: (string-utf8 256),
  issue-date: uint,
  creator-location: (string-utf8 64),
  license-verified: bool
})

(define-map creator-assets principal (list 100 uint))
(define-map verified-creators principal bool)
(define-data-var license-id-counter uint u0)

;; Error codes
(define-constant err-not-creator (err u900))
(define-constant err-not-verifier (err u901))
(define-constant err-license-not-found (err u902))
(define-constant err-permission-restricted (err u903))
(define-constant err-asset-limit-exceeded (err u904))
(define-constant err-invalid-creator-address (err u905))
(define-constant err-invalid-asset-title (err u906))
(define-constant err-invalid-license-terms (err u907))
(define-constant err-invalid-issue-date (err u908))
(define-constant err-invalid-creator-location (err u909))
(define-constant err-invalid-license-id (err u910))

;; Platform administrator for creator verification
(define-constant platform-admin tx-sender)

;; Register verified content creator
(define-public (register-verified-creator (creator principal))
  (begin
    ;; Check if sender is platform administrator
    (asserts! (is-eq tx-sender platform-admin) err-permission-restricted)
    
    ;; Validate creator principal
    (asserts! (not (is-eq creator 'SP000000000000000000002Q6VF78)) err-invalid-creator-address)
    
    ;; Add creator to registry
    (ok (map-set verified-creators creator true))
  ))

;; Issue digital asset license
(define-public (issue-digital-license
  (asset-title (string-utf8 64))
  (license-terms (string-utf8 256))
  (issue-date uint)
  (creator-location (string-utf8 64)))
  (let
    ((license-id (var-get license-id-counter))
     (creator tx-sender)
     (current-assets (default-to (list) (map-get? creator-assets creator))))
    
    ;; Validate inputs
    (asserts! (> (len asset-title) u0) err-invalid-asset-title)
    (asserts! (> (len license-terms) u0) err-invalid-license-terms)
    (asserts! (> issue-date u0) err-invalid-issue-date)
    (asserts! (> (len creator-location) u0) err-invalid-creator-location)
    
    ;; Check asset limit
    (asserts! (< (len current-assets) u100) err-asset-limit-exceeded)
    
    ;; Store license information
    (map-set digital-licenses license-id {
      creator: creator,
      asset-title: asset-title,
      license-terms: license-terms,
      issue-date: issue-date,
      creator-location: creator-location,
      license-verified: false
    })
    
    ;; Update creator assets
    (let
      ((updated-assets (unwrap-panic (as-max-len? (concat (list license-id) current-assets) u100))))
      (map-set creator-assets creator updated-assets)
    )
    
    ;; Increment license ID counter
    (var-set license-id-counter (+ license-id u1))
    
    (ok license-id)))

;; Verify digital license
(define-public (verify-digital-license (license-id uint))
  (begin
    ;; Validate license ID
    (asserts! (< license-id (var-get license-id-counter)) err-invalid-license-id)
    
    (let
      ((license (unwrap! (map-get? digital-licenses license-id) err-license-not-found)))
      
      ;; Check if sender is verified creator
      (asserts! (default-to false (map-get? verified-creators tx-sender)) err-not-verifier)
      
      ;; Update license verification status
      (ok (map-set digital-licenses license-id (merge license {license-verified: true})))
    )
  ))

;; Get digital license details
(define-read-only (get-digital-license (license-id uint))
  (map-get? digital-licenses license-id))

;; Get creator assets
(define-read-only (get-creator-assets (creator principal))
  (default-to (list) (map-get? creator-assets creator)))

;; Check verified creator status
(define-read-only (is-verified-creator (address principal))
  (default-to false (map-get? verified-creators address)))

;; Get total licenses
(define-read-only (get-total-licenses)
  (var-get license-id-counter))

;; Get platform stats
(define-read-only (get-platform-stats)
  {
    admin: platform-admin,
    total-licenses: (var-get license-id-counter)
  })