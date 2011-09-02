#lang racket/base

(require racket/match
         racket/file
         racket/path
         racket/port
         "make/make-structs.rkt"
         "js-assembler/package.rkt"
         "resource/structs.rkt"
         "logger.rkt")

(provide (all-defined-out))


(define current-verbose? (make-parameter #f))
(define current-output-dir (make-parameter (build-path (current-directory))))
(define current-write-resources? (make-parameter #t))

(define (same-file? p1 p2)
  (or (equal? (normalize-path p1) (normalize-path p2))
      (bytes=? (call-with-input-file p1 port->bytes)
               (call-with-input-file p2 port->bytes))))


(define (turn-on-logger!)
  (void (thread (lambda ()
                  (let ([receiver
                         (make-log-receiver whalesong-logger
                                            (if (current-verbose?)
                                                'debug
                                                'info))])
                    (let loop ()
                      (let ([msg (sync receiver)])
                        (match msg
                          [(vector level msg data)
                           (fprintf (current-error-port)"~a: ~a\n" level msg)
                           (flush-output (current-error-port))]))
                      (loop)))))))

(define (build f)
  (turn-on-logger!)
  (let-values ([(base filename dir?)
                (split-path f)])
    (let ([output-filename
           (build-path
            (regexp-replace #rx"[.](rkt|ss)$"
                            (path->string filename)
                            ".xhtml"))])
      (unless (directory-exists? (current-output-dir))
        (make-directory* (current-output-dir)))
      (parameterize ([current-on-resource
                      (lambda (r)
                        (log-info (format "Writing resource ~s" (resource-path r)))
                        (cond
                          [(file-exists? (build-path (current-output-dir)
                                                     (resource-key r)))
                           (cond [(same-file? (build-path (current-output-dir)
                                                          (resource-key r))
                                              (resource-path r))
                                  (void)]
                                 [else
                                  (error 'whalesong "Unable to write resource ~s; this will overwrite a file"
                                         (build-path (current-output-dir)
                                                     (resource-key r)))])]
                          [else
                           (copy-file (resource-path r) 
                                      (build-path (current-output-dir)
                                                  (resource-key r)))]))])
        (call-with-output-file* (build-path (current-output-dir) output-filename)
                                (lambda (op)
                                  (package-standalone-xhtml
                                   (make-ModuleSource (build-path f))
                                   op))
                                #:exists 'replace)))))



(define (print-the-runtime)
  (turn-on-logger!)
  (display (get-runtime) (current-output-port)))



(define (get-javascript-code filename)
  (turn-on-logger!)
  (display (get-standalone-code
            (make-ModuleSource (build-path filename)))
           (current-output-port)))