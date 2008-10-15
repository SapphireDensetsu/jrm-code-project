;;-*-mode:lisp;package:user-*-
(or (boundp '*benchmark-result-symbols*)
    (setq *benchmark-result-symbols* nil))
(or (memq '*S104-U1161-MAY13-BENCHMARK* *benchmark-result-symbols*)
    (push '*S104-U1161-MAY13-BENCHMARK* *benchmark-result-symbols*))


(DEFCONST *S104-U1161-MAY13-BENCHMARK-DIGEST* (QUOTE ((BOYER :DISK-WAIT-TIME (8.883) :REAL-TIME (37.0)) (BROWSE :DISK-WAIT-TIME (6.299999997) :REAL-TIME (34.39999998)) (CTAK :DISK-WAIT-TIME (0.0) :REAL-TIME (4.299999997)) (DDERIV :DISK-WAIT-TIME (0.8329999996) :REAL-TIME (7.9)) (DERIV :DISK-WAIT-TIME (1.382999999) :REAL-TIME (7.6)) (DESTRU :DISK-WAIT-TIME (1.049999999) :REAL-TIME (4.9)) (DIV2 :DISK-WAIT-TIME (2.783 3.05) :REAL-TIME (6.6 8.39999999)) (FFT :DISK-WAIT-TIME (0.4 0.083) :REAL-TIME (37.39999998 15.2)) (FPRINT :DISK-WAIT-TIME (6.883) :REAL-TIME (18.19999999)) (FREAD :DISK-WAIT-TIME (0.35) :REAL-TIME (16.19999999)) (FRPOLY :DISK-WAIT-TIME (0.00216 0.00133 0.00266 0.02160000001 0.035 0.0233 0.233 0.2829999998 0.2829999998 1.216 2.215999998 2.132999998) :REAL-TIME (0.011 0.013 0.015 0.12 0.1799999999 0.15 1.299999999 2.3 1.799999999 8.8 19.29999998 12.8)) (PUZZLE :DISK-WAIT-TIME (0.25) :REAL-TIME (27.19999999)) (STAK :DISK-WAIT-TIME (0.0) :REAL-TIME (6.799999997)) (TAK :DISK-WAIT-TIME (0.0) :REAL-TIME (1.5)) (TAKL :DISK-WAIT-TIME (0.016) :REAL-TIME (10.2)) (TAKR :DISK-WAIT-TIME (0.066) :REAL-TIME (1.799999999)) (TPRINT :DISK-WAIT-TIME (0.2999999998) :REAL-TIME (7.299999997)) (TRAVERSE :DISK-WAIT-TIME (0.933 0.05) :REAL-TIME (20.5 136.8999999)) (TRIANG :DISK-WAIT-TIME (0.183) :REAL-TIME (492.7999997)))))
(DEFCONST *S104-U1161-MAY13-BENCHMARK* (QUOTE ((BOYER-1 28.117) (BROWSE-1 28.09999998) (CTAK-1 4.299999997) (DDERIV-1 7.066999998) (DERIV-1 6.217) (DESTRU-1 3.85) (DIV2-1 3.817000002) (DIV2-2 5.34999999) (FFT-1 36.99999997) (FFT-2 15.117000006) (FPRINT-1 11.31699999) (FREAD-1 15.84999999) (FRPOLY-1 0.008839999995) (FRPOLY-2 0.01167) (FRPOLY-3 0.01234) (FRPOLY-4 0.0984) (FRPOLY-5 0.1449999999) (FRPOLY-6 0.1267) (FRPOLY-7 1.066999999) (FRPOLY-8 2.017) (FRPOLY-9 1.516999999) (FRPOLY-10 7.584) (FRPOLY-11 17.08399999) (FRPOLY-12 10.666999996) (PUZZLE-1 26.94999999) (STAK-1 6.799999997) (TAK-1 1.5) (TAKL-1 10.184) (TAKR-1 1.733999999) (TPRINT-1 6.999999996) (TRAVERSE-1 19.567) (TRAVERSE-2 136.8499999) (TRIANG-1 492.6169996))))