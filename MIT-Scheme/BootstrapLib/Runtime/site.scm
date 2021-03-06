(declare (usual-integrations))
;; Site specific initialization

(define-integrable (log->10log10 x)
  (flo:* 4.3429448190325175 x))

(define-integrable (flo:10log10 x)
  (log->10log10 (flo:log x)))

(define-integrable (10log10 x)
  (flo:10log10 (exact->inexact x)))

(define-syntax dotimes
  (syntax-rules ()
     ((dotimes (var ntimes return-value) form0 . forms)
      (do ((var 0 (fix:+ var 1)))
	  ((fix:>= var ntimes) return-value)
        form0 . forms))
     ((dotimes (var ntimes) form0 . forms)
      (dotimes (var ntimes #f) form0 . forms))))

(define (finish-cold-load)
  (define (time-phase phase thunk)
    (display "; Start phase ")
    (display phase)
    (newline)
    (flush-output)
    (let ((start-time (runtime)))
      (let ((answer (thunk)))
	(for-each write-string 
		  (list "; " phase " took "
			(number->string (- (runtime) start-time))
			" ("
			(number->string
			 (10log10 (- (runtime) start-time)))
			")."))
	(newline)
	(flush-output)
	answer)))

  (display "\\BootstrapLib\\runtime\\site")

  (time-phase
   "Initial timing"
   (lambda ()

          (with-working-directory-pathname
      "C:\\Home\\Jrm\\Larceny\\Testsuite\\GC\\"
      (lambda ()
	(time-phase 
	 "Load everything"
	 (lambda () 
	   (load "dynamic.bin")
	   (load "sboyer.bin")
	   (load "lattice.bin")))))

     (time-phase
      "Setup and Run everything once."
      (lambda ()
	(display "; Setup boyer...") (flush-output)
	((access setup-boyer user-initial-environment))
	(newline) (display "; Test boyer...") (flush-output)
	((access test-boyer user-initial-environment) 1)
	(dotimes (i 5)
	  (newline) (display "; dynamic...") (flush-output)
	  ((access doit user-initial-environment))
	  (dotimes (i 5)
  	    (newline) (display "; lattice...") (flush-output)
	    ((access lb3 user-initial-environment))))
	(newline)))

     (time-phase
      "Load rb-tree"
      (lambda () (load-option 'rb-tree)))

     (time-phase
      "Load sf"
      (lambda () (load-option 'sf)))

     (time-phase
      "Load star-parser"
      (lambda () (load-option '*parser)))

     (time-phase
      "Load cref"
      (lambda () (load-option 'cref)))


     (let ()
       (define (boyer)
	 (time-phase
	  "SBoyer>"
	  (lambda ()
	    ((access test-boyer user-initial-environment) 1))))
       (define (dynamic)
	 (time-phase
	  "dynamic>"
	  (lambda ()
	    (dotimes (i 5)
	      ((access doit user-initial-environment))))))
       (define (lattice)
	 (time-phase
	  "lattice lb3>"
	  (lambda ()
	    (dotimes (i 25)
	      ((access lb3 user-initial-environment))))))
       (let* ((benchmarks
	       (append (make-list 100 boyer)
		       (make-list 100 dynamic)
		       (make-list 100 lattice)))
	      (noted (map (lambda (x)
			    (cons (random 100000) x))
			  benchmarks))
	      (sorted (sort noted (lambda (l r) (< (car l) (car r)))))
	      (stripped (map cdr sorted)))
	 (for-each (lambda (b) (b)) stripped)))

     ))

  (with-working-directory-pathname 
   "C:\\jrm-code-project\\Mit-scheme\\StagingLib\\Runtime\\"
   (lambda () 
     (load "runtime.sf")
     (sf "site.scm")))

  (with-working-directory-pathname 
   "C:\\jrm-code-project\\Mit-scheme\\StagingLib\\Sf\\"
   (lambda () (load "sf.sf")))

  (with-working-directory-pathname 
   "C:\\jrm-code-project\\Mit-scheme\\StagingLib\\star-parser\\"
   (lambda () 
     (fluid-let ((sf/default-syntax-table (->environment '(RUNTIME))))
       (sf-directory ".")
       (cref/generate-constructors "parser" 'ALL))))

  (with-working-directory-pathname 
   "C:\\jrm-code-project\\Mit-scheme\\StagingLib\\Cref\\"
   (lambda () (load "cref.sf")))

  (cd "C:\\Home\\Jrm\\Larceny\\Testsuite\\GC\\")

  (time-phase "Load dynamic" (lambda () (load "dynamic.bin")))
  (time-phase "Load sboyer"  (lambda () (load "sboyer.bin")))
  (time-phase "Load lattice" (lambda () (load "lattice.bin")))
;  (load "lattice.bin")
  (time-phase "Run Dynamic"  (access doit user-initial-environment))
;  (load "sboyer.bin")
  ((access setup-boyer user-initial-environment))

    (time-phase "Run Sboyer"
		(lambda () ((access test-boyer user-initial-environment) 1)))
;    (%exit 1)

;  (do ((i 0 (+ i 1)))
;      ((>= i 250) (%exit 1))
;    (time-phase "Run Sboyer"
;		(lambda () ((access test-boyer user-initial-environment) 1)))
;    ((access simple-random-state (package/environment (find-package '(runtime random-number))))))

  (time-phase "Load sboyer1"  (lambda () (load "sboyer1.bin")))
  ((access setup-boyer1 user-initial-environment))

    (time-phase "Run Sboyer1"
		(lambda () ((access test-boyer1 user-initial-environment) 1)))



;  (do ((i 0 (+ i 1)))
;      ((> i 50))
  (time-phase "Run lattice"  (access lb3 user-initial-environment))
;  )


   (identify-world)

  (cd "c:\\GitRepository\\mit-scheme\\src\\runtime\\")
;  (load "runtime.sf")
  (%exit 1)
  )
