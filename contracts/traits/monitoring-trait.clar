;; Monitoring Trait
;; Defines the standard interface for monitoring in the Conxian protocol

(define-trait monitoring-trait
  (
    ;; Log an event with a severity level
    (log-event (component (string-ascii 32)) 
               (event-type (string-ascii 32)) 
               (severity uint) 
               (message (string-ascii 256)) 
               (data (optional {})) 
               (response bool uint))
    
    ;; Get events for a component
    (get-events (component (string-ascii 32)) 
                (limit uint) 
                (offset uint) 
                (response (list 100 (tuple (id uint) 
                                         (event-type (string-ascii 32)) 
                                         (severity uint) 
                                         (message (string-ascii 256)) 
                                         (block-height uint) 
                                         (data (optional {})))) 
                         uint))
    
    ;; Get event by ID
    (get-event (event-id uint) 
               (response (tuple (id uint) 
                              (component (string-ascii 32)) 
                              (event-type (string-ascii 32)) 
                              (severity uint) 
                              (message (string-ascii 256)) 
                              (block-height uint) 
                              (data (optional {}))) 
                        uint))
    
    ;; Get component health status
    (get-health-status (component (string-ascii 32)) 
                      (response (tuple (status uint) 
                                     (last-updated uint) 
                                     (uptime uint) 
                                     (error-count uint) 
                                     (warning-count uint)) 
                               uint))
    
    ;; Set alert threshold for a component
    (set-alert-threshold (component (string-ascii 32)) 
                         (alert-type (string-ascii 32)) 
                         (threshold uint) 
                         (response bool uint))
    
    ;; Get the admin address
    (get-admin () (response principal uint))
    
    ;; Transfer admin rights
    (set-admin (new-admin principal) (response bool uint))
  )
)
