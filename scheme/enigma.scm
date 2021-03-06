(declare (usual-integrations))

(define-integrable (dotimes count thunk)
  (let loop ((i 0)
             (limit count))
    (if (fix:< i count)
        (begin (thunk i)
               (loop (fix:1+ i) limit)))))

(define-integrable *rotor-size* 27)

(define (make-null-rotor)
  (let ((rotor (make-string *rotor-size*)))
    (dotimes *rotor-size*
             (lambda (i) (vector-8b-set! rotor i i)))
    rotor))

(define (invert-rotor! rotor inverse)
  (dotimes *rotor-size*
           (lambda (i)
             (vector-8b-set! inverse (vector-8b-ref rotor i) i))))

(define (make-boring-reflector)
  (let ((reflector (make-string *rotor-size*)))
    (dotimes (inexact->exact (floor (/ *rotor-size* 2)))
             (lambda (i)
               (vector-8b-set! reflector i (+ i (inexact->exact (floor (/ *rotor-size* 2)))))
               (vector-8b-set! reflector (+ i (inexact->exact (floor (/ *rotor-size* 2)))) i)))
    reflector))

(define-integrable (rotor-add a b)
  (let ((sum (fix:+ a b)))
    (if (fix:< sum *rotor-size*)
        sum
        (fix:- sum *rotor-size*))))

(define-integrable (rotor-sub a b)
  (let ((result (fix:- a b)))
    (if (fix:< result 0)
        (fix:+ result *rotor-size*)
        result)))

(define-integrable (decode-character i)
  (string-ref " abcdefghijklmnopqrstuvwxyz" i))

(define-integrable (encode-character c)
  (vector-8b-ref "�������������������������������� ��������������������������������	
������	
�����" (char->ascii c)))

(define (testit message)
  (let ((rotor (make-string *rotor-size*))
        (reflector (make-string *rotor-size*)))
    (dotimes *rotor-size* 
             (lambda (i) 
               (vector-8b-set! rotor i (rotor-add i 1))))
    (dotimes (inexact->exact (floor (/ *rotor-size* 2)))
             (lambda (i)
               (vector-8b-set! reflector (* i 2) (1+ (* i 2)))
               (vector-8b-set! reflector (1+ (* i 2)) (* i 2))))
    (enigma message rotor reflector)))

(define *inverse-rotor* (make-string *rotor-size*))

(define (enigma input rotor reflector)
  (declare (ignore-reference-traps (set *inverse-rotor*)))
  (let ((output (make-string *rotor-size*)))
    (invert-rotor! rotor *inverse-rotor*)
    (dotimes *rotor-size*
             (lambda (i)
            (string-set! output i
                         (decode-character
                          (rotor-add
                           (vector-8b-ref *inverse-rotor*
                                          (rotor-sub 
                                           (vector-8b-ref reflector
                                                          (rotor-sub
                                                           (vector-8b-ref rotor 
                                                                          (rotor-add i (encode-character (string-ref input i))))
                                                           i))
                                           i))
                           i)))))
    output))



                       




