;-*- Mode:MIDAS; Readtable:ZL; Base:8; Fonts:(CPTFONT CPTFONTB) -*-
;;;
;;; (c) Copyright 1984 - Lisp Machine, Inc.
;;;

; __________________________
; | There is no problem in |
; | computer science that  |
; |  cannot be solved by   |
; |    another level of    |
; |      indirection       |
; |________________________|


;Written by RMS.  You are welcome to use this,
;though it is not likely to do you much good.
;Documentation, etc. by JRM.

;;;*****************
;;; NOTE:  There is a fundamental bug in the implementation of stack
;;; closures relative to the current way the microcode does things.
;;; It was deemed easier to remove the stack closures than to rewrite
;;; large portions of the microcode.  Therefore, this file is no longer
;;; used.

(defconst uc-stack-closure '(

;;; Here is how lexical closures work
;;; A lexical closure consists of a piece of code and an environment to
;;; resolve free variables in.  The code is implemented by a FEF and the
;;; environment is implemented as a list of vectors.  Each car in the
;;; environment is a lexical environment frame which is a vector of
;;; variable bindings. As there is no way to extend the number of variables
;;; in a lexical environment, a vector saves space, but more
;;; importantly, since the lexically visible variables can be known at
;;; compile time, the compiler can generate code that simply "arefs" a
;;; given frame and finds the correct value of a lexical variable.  A
;;; lexical environment is a list of these vectors.

;;; A closure (any kind, stack or regular) is implemented like this:
;;;   (dtp-{stack-}closure          )
;;;                              |
;;;                 /------------/ pointer to closure
;;;                
;;;   (cdr-next dtp-fef-pointer   --)--- points to a fef containing the code
;;;   (cdr-nil  dtp-list            )
;;;                              |
;;;                 /------------/ pointer to lexical environment
;;;                
;;;   (cdr-normal dtp-list        --)--- points to lexical frame
;;;   (cdr-error  dtp-list        --)--- points to next environment

;;; This would be too easy if it weren't for efficiency hacks.  The
;;; following things are noted:
;;; 1) Some closures are only used in downward funargs and will never be
;;;    needed after this dynamic frame is exited.  The extent of these
;;;    closures is dynamic and follows stack discipline, so they can be
;;;    consed on the stack giving the garbage collector a break.
;;;    (Actually, this was done so that you wouldn't have to use a
;;;    losing garbage collector.)  It is not possible to tell if a
;;;    funarg is to be used in a downward only direction if it is passed
;;;    to a procedure external to the one currently running.
;;; 2) The uppermost lexical frame of the closure when it is created is
;;;    the current dynamic frame.  The args and locals of the frame are
;;;    the ones that are seen by the code.  They cannot be copied out of
;;;    the frame.
;;; 3) Not all the args and locals of a dynamic frame need appear in a
;;;    lexical frame.  Which args and locals are needed can be
;;;    determined at compile time.  This will save space and allow the
;;;    garbage collector to reclaim inaccessable objects that would be
;;;    otherwise saved if we kept the whole dynamic environment.
;;; 4) Nested lexical contexts can be "flattened" if the code that
;;;    creates them is only run once.  See page 87 - 89 (base 10) of the
;;;    common lisp book for examples of flattenable and unflattenable
;;;    contexts.  A corollary to this is the fact that a binding which
;;;    is lexically visible to different closures and which should be
;;;    distinct in each closure can be shared among them if the code
;;;    never mutates the variable.
;;;
;;; The above is taken advantage of by the below.
;;; Efficiency hacks:
;;; 1) We take an optimistic approach and assume all funargs are
;;;    downward.  Lexical frames and closures are initially allocated on
;;;    the stack.  All pointers made to the closure are labeled
;;;    dtp-stack-closure.  If a dtp-stack-closure is ever moved anywhere
;;;    but to a frame closer to the top of the stack, it becomes
;;;    necessary to copy the closure and the lexical frame
;;;    out of the stack and into the heap.  All closures that
;;;    are in the heap are labeled dtp-closure.
;;; 2) The lexical frame when it is created contains
;;;    external-value-cell-pointers (EVCP's) to the actual locations in
;;;    the stack of the args and locals.  This makes it possible to
;;;    smash the args and locals from downward funargs.
;;; 3) The lexical frame is created only with those bindings needed by
;;;    the closure.  This is determined by looking at the FEF of the
;;;    current procedure (not the one you are closing!).  Two slots
;;;    before the unboxed instructions is a list which is a template for
;;;    making lexical frames.  It is a list of fixnums in which the low
;;;    twelve bits specifies which argument or local appears and the
;;;    sign bit indicates whether it is an arg or local.  This list is
;;;    arranged in "reverse" order, i.e. the first argument is the last
;;;    on the list and the last local is the first element of the list.
;;;    The list is stored in reverse order because the microcode just
;;;    happens to make a pointer to the box just after the lexical
;;;    frame.  It then constructs the lexical frame by decrementing the
;;;    pointer and cdring down the map in the FEF.
;;; 4) The contexts are in fact flattened by the compiler.  The compiler
;;;    makes sure variable references go to the right slot, so there are
;;;    no name conflicts.  In order to take advantage of sharing, we
;;;    assume that all lexical frames closed in the current dynamic
;;;    frame can be shared and only cons up one initially.  The compiler
;;;    issues commands STACK-CLOSURE-DISCONNECT to force a
;;;    splitting of shared frames.  This copies the current frame into
;;;    the heap.  Two frames which were EQ are now EQUAL (i.e. identical
;;;    copies instead of being identical).  Then, the compiler does a
;;;    STACK-CLOSURE-UNSHARE giving it an argument which specifies which
;;;    lexical slot to unshare.  Remember that the lexical frame
;;;    initially contains EVCP's to the args and locals.
;;;    STACK-CLOSURE-UNSHARE "snaps" the invisible pointer and copies
;;;    the arg into the lexical frame.  The frame will still share the
;;;    other args and locals by virtue of the remaining EVCP'S
;;;
;;;    When it finally comes time to exit the stack frame, if there are
;;;    any outstanding closures in the heap pointing to a lexical frame
;;;    which is stack consed in the current stack frame, we copy the
;;;    stack frame to the heap and snap all the EVCP's in it.  We then
;;;    go to each closure pointing sharing any of the args or locals and
;;;    make their EVCP's point to the copy we just constructed.  Now we
;;;    can exit the frame.  Note that in order to find each closure in
;;;    the heap, we keep around a list of all closures disconnected from
;;;    this frame.

;;; How a frame with closures is set up in the first place:

;Frame begins here  (dtp-fix) ;bits controlling return
;                   (dtp-fix)
;                 (DTP-FEF-POINTER   --)---> to code for the frame.
;Arguments        (cdr-next ......)
; cdr codes are   (cdr-next ......)
; set right               : <more args>
;                         :
; last arg        (cdr-nil  ......)
;Locals           (...............) <--- A-LOCALP if this is the current function
; random boxed    (...............)
; objects                 : <more locals>
;                         :
;    Stack closures are allocated in the area for locals and take up
;    four local slots.  They are not really locals, they just live here.
;    The <pointer to next cell> is the pointer to the lexical
;    environment chain which just happens to be in the next cell.
; stack closure   (cdr-next   dtp-fef-pointer  --)---> points to closure code
;                 (cdr-nil    dtp-list  <points to next cell>)
;                 (cdr-normal dtp-list  <points to lexical frame>)
;                 (cdr-error  dtp-list  <points to next higher context>)
;                         :  <more stack closures>
;                         :
;    The lexical frame also takes up locals.  It is constructed from the
;    map found two slots before the instructions in the FEF.  We work
;    here on the assumption that we will not need more than one lexical
;    frame (in the case where all variables are or can be shared).
;                 (dtp-list <pointer to beginning of frame>)
; lexical frame   (cdr-next dtp-external-value-cell-pointer <pointer to local or arg>)
;                 (cdr-next dtp-external-value-cell-pointer <pointer to local or arg>)
;                         : <more lexical slots>
;                         :
; next-to-last-local      (dtp-list <pointer to lexical frame>)
; last-local       Contains a list of all copies made of the lexical
;                  frame so we can set them up right when we exit this
;                  dynamic frame and deallocate storage for the
;                  variables.
;
; The top of the stack is here.

;;; Notes on the above diagram.
;;; 1) The word just before the lexical frame is used by
;;;    COPY-STACK-ENVIRONMENT-INTO-HEAP to locate the beginning of the stack
;;;    frame.
;;; 2) The lexical frame need not be there.  All the local slots
;;;    are set to point to nil when the frame is entered.  When it comes
;;;    time to make a stack closure, the next to last local slot is
;;;    checked to see if a lexical frame has been made.  If it has not,
;;;    (i.e. it is nil) the FEF is looked at to find a list of args and
;;;    locals to forward the slots in the lexical frame to.  If the list
;;;    in the FEF is nil, this means that the current frame is empty.
;;;    In this case, the next to last local is set to T indicating an
;;;    empty frame.
;;; 3) In the comments above I used the words "lexical frame" to
;;;    indicate what it is that holds the bindings in an environment.
;;;    In the below code, it is called a "lexical frame"  I
;;;    apologize to those of you who tried to figure out what was going
;;;    on by examining my comments vs. the code before reading this.
;;;    "Lexical frame" is the use, "lexical frame" is the
;;;    implementation.
;;; 4) A-LEXICAL-ENVIRONMENT will point to the context outside of this
;;;    frame so all closures created in this frame will contain a copy
;;;    of A-LEXICAL-ENVIRONMENT.


;;; When we copy a stack closure into the heap, we forward the copy on
;;; the stack.  We can't use HEADER-FORWARD because putting that in a
;;; structure will confuse other things.  What we do is put
;;; external-value-cell-forwards in the fef pointer and the environment
;;; pointer in the stack closure to point to the corresponding cells in
;;; the heap pointer.  This does not really forward the closure, but it
;;; will do the trick because the stack closure never moves until it is
;;; deallocated and anything that remains around after that sees only
;;; the heap allocated version.  The lexical frame (the stack closure
;;; vector) is not forwarded.

;;; The last word in the frame is a pointer to every copy of the lexical
;;; frame in the world.  If the stack frame is exited, we copy the
;;; lexical frame and go to each of the other copies and change their
;;; EVCP's to point to our new copy.

;;; This is the old comment.
;;; Copy a DTP-STACK-CLOSURE when it is stored anywhere but
;;; into the same stack it points at, and farther down than where it points.
;;; There is no way to forward the stack closure to the copy,
;;; because only header-forward works to forward a list's car and cdr,
;;; and putting that inside a structure will confuse other things.
;;; So we stick an external-value-cell-pointer into the stack closure
;;; pointing at the copy.  This does not forward it as far as the
;;; low levels of the system is concerned!  But as long as the
;;; stack closure still exists, that's ok; the evcp forwards only the car
;;; of the stack closure, but forwards it to the car of the copy,
;;; which contains the correct value.

STACK-CLOSURE-TRAP
     ;Here from GC-WRITE-TEST if data type is DTP-STACK-CLOSURE.
     ;The vma should point to the place you want the closure to appear.
     ;If the vma is nil (old version) illop will be called.
  ((m-tem) q-pointer md)
  ((m-pgf-tem) q-pointer vma)
     ;If storing into the same stack and inward from where it points, don't copy.
  (jump-less-than m-tem a-qlpdlo stack-closure-trap-really)
  (jump-less-than m-pgf-tem a-tem stack-closure-trap-really)
; (jump-less-than m-pgf-tem a-qlpdlh trans-drop-through)
  (popj-less-than m-pgf-tem a-qlpdlh)

stack-closure-trap-really
     ;Here if the stack-closure is being stored into a place it should not be.
     ;If coming from PDL buffer dumper, don't copy.
     ;If it was ok to put the pointer there originally, it is still ok there.
     ;(Note, additional hair would be needed to avoid lossage if it copied in this case.)
; (jump-if-bit-set (byte-field 1 0) read-i-arg trans-drop-through)
  (jump-if-bit-set m-no-stack-closures closure-trap)
  (call-if-bit-set (byte-field 1 2) read-i-arg illop)  ;lose if attempted recursive call
                                        ;this probably has to be fixed.
  (popj-if-bit-set (byte-field 1 0) read-i-arg)
     ;Also POPJ if called from scavenger.
  (popj-if-bit-set (byte-field 1 1) read-i-arg)
     ;Also POPJ if called from extra-pdl-purge. .. however, it cant get here from there
     ; anyway due to a random test it makes.  Leave this here just so you think about the
     ; possible lossage...
 ;(popj-if-bit-set (byte-field 1 4) read-i-arg)
     ;Save original cdr code of word containing the stack closure, and save its address.
  ((pdl-push) q-cdr-code md (a-constant (byte-value q-data-type dtp-fix)))
  ((pdl-push) vma)
     ;If EVCP in stack, someone already copied the closure into the heap.  Otherwise,
     ;we must do it ourselves.
  ((vma-start-read) md)
  (check-page-read)
  (check-data-type-call-not-equal md m-tem dtp-external-value-cell-pointer
                        stack-closure-copy)

stack-closure-store-copy
     ;Now, we are guaranteed a copy of the closure in the heap.  All the evcp "forwards"
     ;are set up.
     ;The copy is in md, make it dtp-closure.
  ((md m-tem) q-pointer md (a-constant (byte-value q-data-type dtp-closure)))
  ((vma) c-pdl-buffer-pointer-pop)      ;Get back original address referenced,
  ((md) dpb pdl-pop q-cdr-code a-tem)   ;Merge in original CDR-code of memory word.
     ;Old style is not allowed.
; (jump-equal vma a-v-nil trans-drop-through)   ;Or NIL => just leave value in MD.
  (call-equal vma a-v-nil illop)
     ;Write the location with the closure pointer.  Don't forget to test for volatility.
  ((vma-start-write) vma)
  (check-page-write)
     ;Make sure we don't recurse.
  (gc-write-test-volatility-stack-closure-copy)   ;850726
  (popj)

STACK-CLOSURE-COPY
     ;This stack-closure has not yet had a copy made.
     ;The original stack-closure object is now in VMA.
     ;Returns with a pointer to the copy in MD.
     ;We save the inhibit-scavenging-flag so we can turn off scavenging and then restore
     ;the flag.
  ((pdl-push) a-inhibit-scavenging-flag)
     ;Save pointer to stack-consed closure for later reference.
  ((pdl-push) vma)

     ;Make sure all the cells of the environment list are in newspace.
     ;Or rather, that their containing stacks are in newspace.
     ; Once the cells are in newspace, we can make copies of them and do all
     ; sorts of nasty stuff without worrying about bad pointers.
     ; Our biggest problem here is making pointers to cells with EVCP "forwards" in
     ; them.
     ; The closure is on the stack, so the tail of the environment chain is 3
     ; down from the closure.  The head of the chain points into this frame
     ; and does not need to be transported.
  ((vma-start-read) add vma (a-constant 3))
  (check-page-read)             ;MD has ptr to list, VMA as addr of that ptr.
  (call transport-lexical-environment)

     ; Now we "turn off" the scavenger to prevent it finding EVCP's in the heap.
     ; Also save the registers that the transporter uses.
  (call-xct-next trans-copy-save)
 ((a-inhibit-scavenging-flag) a-v-true)

     ; At this point, we wish to copy the entire environment chain, so we
     ; index 2 off the closure (it is still on the stack so we can do this).
  ((vma-start-read) add pdl-top (a-constant 2))
  (check-page-read)
  (call copy-stack-environment-into-heap)

     ;Get the address of the copy just made of the first cell of the environment-list.  Save it.
  ((vma-start-read) add pdl-top (a-constant 2))
  (check-page-read)
  ((c-pdl-buffer-pointer-push) dpb md q-pointer
                               (a-constant (byte-value q-data-type dtp-list)))

     ;Go through again, splicing the EVCPs out
     ;so that the new copies point directly at the next one.
     ;Snap-evcps-out-of-heap-environment-copy doesn't want to see an evcp in the cdr.
     ;We fake out the error trap in snap-evcps-out-of-heap-environment-copy by putting a dtp-list
     ;on md.
  (call-xct-next snap-evcps-out-of-heap-environment-copy)
 ((md) q-pointer md (a-constant (byte-value q-data-type dtp-list)))

     ;Copy the closure itself.
  ((m-b) (a-constant 2))
  (call-xct-next allocate-list-storage)
 ((m-s) dpb m-zero q-all-but-typed-pointer a-background-cons-area)

     ;Store the environment chain in the cdr of the copy.
  ((vma) add m-t (a-constant 1))
  ((md-start-write) dpb q-typed-pointer pdl-pop
                (a-constant (byte-value q-cdr-code cdr-nil)))
  (check-page-write)
  (gc-write-test-volatility-stack-closure-copy)

     ;Get back ptr to original stack closure, and copy the first slot in the car of the copy.
  ((vma-start-read m-k) pdl-pop)
  (check-page-read)
  ((vma-start-write) m-t)
  (check-page-write)
  (gc-write-test-volatility-stack-closure-copy)

     ;Make the closure on the stack point at the copy with an EVCP.
  ((md) dpb m-t q-pointer
                  (a-constant (plus (byte-value q-cdr-code cdr-next)
                                    (byte-value q-data-type dtp-external-value-cell-pointer))))
  ((vma-start-write) m-k)
  (check-page-write)
  (gc-write-test-volatility-stack-closure-copy)
     ;Restore everything and turn the scavenger back on.  We count on TRANS-COPY-RESTORE to
     ;popj for us.
  (jump-xct-next trans-copy-restore)
 ((a-inhibit-scavenging-flag) pdl-pop)


;Transport-lexical-environment
;Copy-stack-environment-into-heap
;snap-evcps-out-of-heap-environment-copy
;One way to copy and snap a non circular list in O(3n) time. *sigh*

;TRANSPORT-LEXICAL-ENVIRONMENT
;       ((MD) Q-TYPED-POINTER MD)
;       (POPJ-EQUAL MD A-V-NIL)
;       (DISPATCH TRANSPORT MD)
;; The CDRs of the environment chain need to be transported for COPY-STACK-ENVIRONMENT-INTO-HEAP,
;; below, for obvious reasons.  However, the CARs also need to be transported, for
;; SNAP-EVCPS-OUT-OF-HEAP-ENVIRONMENT-COPY,
;; which overwrites some of the CDR pointers with CAR pointers
;; in some circumstances.  (What SNAP-EVCPS-OUT-OF-HEAP-ENVIRONMENT-COPY is really trying to do is
;; anyone's guess... in fact, you could say that about a lot of this code.)  KHS 851221.
;        ((vma-start-read) md)
;        (check-page-read)
;        (dispatch transport-scav md)
;       ((VMA-START-READ) M+1 vma)
;       (CHECK-PAGE-READ)
;       (JUMP TRANSPORT-LEXICAL-ENVIRONMENT)

TRANSPORT-LEXICAL-ENVIRONMENT
     ;Make sure that all the cells of the list pointed to by MD
     ;have been copied into newspace if necessary.
     ;Actually, the entire stacks that contain them are copied.

     ;Transport md, external-value-cell-pointers are not invisible.
  ((md) q-typed-pointer md)
  (dispatch transport-no-evcp-for-stack-env md)
     ;If md is nil, we quit
  (popj-equal md a-v-nil)
     ;Error check, if md is not dtp-list, we have an illegal stack environment.
  (check-data-type-call-not-equal md m-tem dtp-list illop)

     ;Save pointer to pair and read the car.  We have to transport the car, too.
  ((pdl-push) md)
  ((vma-start-read) md)
  (check-page-read)
  (dispatch transport-no-evcp-for-stack-env md)
     ;If we don't run into one of those EVCP's we cdr.
  (jump-data-type-not-equal md
                  (a-constant (byte-value q-data-type dtp-external-value-cell-pointer))
                  transport-lexical-environment-no-forward)

     ;Otherwise, we indirect through it.
     ;MD is the car, but we pretend it was the cdr of the previous.
     ;We fool the error check above by hacking the type field.
  (jump-xct-next transport-lexical-environment pdl-pop)
 ((md) q-pointer md (a-constant (byte-value q-data-type dtp-list)))

transport-lexical-environment-no-forward
     ;We just cdr off the saved MD.
  ((vma-start-read) m+1 pdl-pop)
  (check-page-read) ;transport for this is at the top of the loop.
  (jump transport-lexical-environment)

;;; This code has the bug it was designed to detect built into it!  See
;;; ILLOP-IF-ILLEGAL-STACK-ENV-EVCP-FORWARD
;;;; Calls illop if md points to something that cannot be considered a
;;;; stack environment.

;ILLOP-IF-ILLEGAL-STACK-ENV
;; If md is nil, we are done.  If it is not DTP-LIST, we lost.
;       ((md) q-typed-pointer md)
;       (popj-equal md a-v-nil)
;       (check-data-type-call-not-equal md m-tem dtp-list illop)

;ILLOP-IF-ILLEGAL-STACK-ENV-1
;; If car of md is a gc-forward or an evcp "forward", we follow it.
;; Otherwise, we cdr.
;       ((pdl-push) md)
;       ((vma-start-read) md)
;       (check-page-read-no-interrupt)
;       (jump-data-type-equal md (a-constant (byte-value q-data-type dtp-gc-forward))
;               illop-if-illegal-stack-env-gc-forward)
;       (jump-data-type-equal md (a-constant (byte-value q-data-type dtp-external-value-cell-pointer))
;               illop-if-illegal-stack-env-evcp-forward)
;       ((vma-start-read) m+1 pdl-pop)
;       (check-page-read-no-interrupt)
;       (jump illop-if-illegal-stack-env)

;ILLOP-IF-ILLEGAL-STACK-ENV-EVCP-FORWARD
;; We should only find evcp "forwards" on the stack.  Here we check to
;; see if what we read is in a pdl area.
; Bogus test, the status code is not set up by d-get-map-bits, only the meta
; bits.
;       (dispatch l2-map-status-code d-get-map-bits)
;       ((m-tem) l2-map-status-code)
;       (call-not-equal m-tem (a-constant 5) illop)

;ILLOP-IF-ILLEGAL-STACK-ENV-GC-FORWARD
;; We assume that gc-forwards and evcp "forwards" used to be lists.  We
;; don't have a data type, so when we loop, we cdr at random.  It should
;; be legitimate, but if we believed this, we wouldn't be running this
;; function anyway.
;       (jump illop-if-illegal-stack-env-1 pdl-pop)

(begin-comment) zwei lossage (end-comment)

;;; The cells that make up the environment chain (the pointers to the
;;; frames, not the frames themselves) may be located completely on the
;;; stack in local slots in stack closures.  COPY-STACK-ENVIRONMENT-INTO-HEAP
;;; cdrs down the environment chain copying the list out into the heap
;;; and replacing the stack cells with evcp's to the copy.
;;; NOTE:  This must be called with the stack environment in newspace, and
;;; the scavenger off.  See STACK-CLOSURE-COPY

;;; We copy the stack environment chain into a linked list in the heap.
;;; We "forward" the stack versions of this with evcp's to the copy.  If
;;; we find an evcp already in the stack, someone else must have copied
;;; part of the environment earlier, so we can quit.

COPY-STACK-ENVIRONMENT-INTO-HEAP
     ;We come to here with the vma pointing to the car of the first pair in the
     ;environment chain.
     ;(This is only called from stack-closure-copy and
     ;that only will copy a stack closure).  We quit when we reach an evcp.  We could
     ;snap through at that point, but we will leave it to snap-evcps-out-of-heap-environment-copy.

     ;When we hit an evcp, we are done.  SNAP-EVCPS-OUT-OF-HEAP-ENVIRONMENT-COPY snaps it.
  (popj-data-type-equal md
          (a-constant (byte-value q-data-type dtp-external-value-cell-pointer)))

     ;The stack env may contian a heap environment as its tail.  In this case, we don't want
     ;to copy it.
     ;If the pointer does not point to a pdl area, we stop copying.
     ;Put pointer in md to get the map bits.  Restore vma.
  ((pdl-push) md)
  ((md) vma)
  (no-op) ;let the maps settle.
  (dispatch l2-map-status-code d-get-map-bits)
  ((m-tem) l2-map-status-code)

     ;Error check to see if we are getting legit values.
  (call-equal m-tem (a-constant 1) illop)
  (call-equal m-tem (a-constant 2) illop)
  (call-equal m-tem (a-constant 6) illop)

  ((md) pdl-pop)
     ;A 5 from the l2-map-status-code means it may be a pdl.  Quit if it isn't.
  (popj-not-equal m-tem (a-constant 5))

     ;Save vma for later "forwarding".
  ((pdl-push) vma)
     ;Push car of env onto pdl for QCONS.
  ((pdl-push) q-typed-pointer md)
     ;Push cdr of env onto pdl.
  ((vma-start-read) m+1 vma)
  (check-page-read)
  ((m-tem) q-typed-pointer c-pdl-buffer-pointer) ;save car for a second.
  ((pdl-push) q-typed-pointer md)
     ;The car is either T or a lexical frame.  If it is a lexical frame, we need to mark
     ;this stack frame to copy the lexical frame on exit.  If it is T, we don't.
  (jump-equal m-tem a-v-true copy-stack-environment-into-heap-dont-mark-frame)
     ;The word just before the lexical frame points to the beginning of the frame
  ((vma-start-read) sub m-tem (a-constant 1))
  (check-page-read)
     ;The word just before the stack frame, which must be dtp-fix, contains the bit
     ;which means copy lexical frame on exit.
  ((vma-start-read) add md (a-constant (eval %lp-entry-state)))
  (check-page-read)
  (check-data-type-call-not-equal md m-tem dtp-fix illop)
     ;Turn it on.  Note, we are writing a fixnum, no need to check volatility.
  ((md-start-write) ior md
          (a-constant (byte-value (lisp-byte %%lp-ens-environment-pointer-points-here) 1)))
  (check-page-write)

     ;We have to turn on the frame's attention bit.  It is somewhere near the beginning
     ;of the frame.
  ((vma-start-read) add vma
          (a-constant (difference (eval %lp-call-state) (eval %lp-entry-state))))
  (check-page-read)
  (check-data-type-call-not-equal md m-tem dtp-fix illop)
  ((md-start-write) ior md (a-constant (byte-value %%lp-cls-attention 1)))
  (check-page-write) ;writing a fixnum, no volatility

copy-stack-environment-into-heap-dont-mark-frame
     ;When we get to here, the new car and cdr are on the stack, qcons takes args from the stack
     ;and in m-s, so we just call.
  (call-xct-next qcons)
 ((m-s) dpb m-zero q-all-but-typed-pointer a-background-cons-area)
     ;QCONS returns a pointer to the cons in m-t.  Now we have to "forward" the pair
     ;we just made to point to the copy.
  ((vma) pdl-pop)
  ((md-start-write) dpb m-t q-pointer
          (a-constant (plus (byte-value q-cdr-code cdr-normal)
                            (byte-value q-data-type dtp-external-value-cell-pointer))))
  (check-page-write)
     ;Wrote a pointer.
  (gc-write-test-volatility-stack-closure-copy)

     ;Now, we look at the cdr.  If it is nil, we are done, if not, we just
     ;load it into the vma and loop back to copy it.
  ((vma-start-read) m+1 vma)
  (check-page-read)
  ((m-tem) q-typed-pointer md)
  (popj-equal m-tem a-v-nil)
  ((vma-start-read) md)
  (check-page-read)
  (jump copy-stack-environment-into-heap)

;;; COPY-STACK-ENVIRONMENT-INTO-HEAP quits when it finds an EVCP.  Everything
;;; beyond that EVCP must be in the heap.  However,
;;; COPY-STACK-ENVIRONMENT-INTO-HEAP does not snap through the EVCP.
;;; SNAP-EVCPS-OUT-OF-HEAP-ENVIRONMENT-COPY does.  This is because we are not using
;;; real forwarding on the stack environments but are just faking it
;;; with EVCP's.

;Snap out any EVCPs in the cells of the list that MD points to.
;Replace each cdr-pointer to a cell that has an EVCP in its car
;with a pointer to where the EVCP points.
;TRANSPORT-LEXICAL-ENVIRONMENT, followed by COPY-STACK-ENVIRONMENT-INTO-HEAP and this,
;is a non-recursive way of copying and snapping an entire list of any length.
;Note that this must act on the start of the copy, not the start
;of the original list.
;SNAP-EVCPS-OUT-OF-HEAP-ENVIRONMENT-COPY
;;Get the first cell's cdr.
;       ((VMA-START-READ M-A) M+1 MD)
;       (CHECK-PAGE-READ)
;       ((M-TEM) Q-TYPED-POINTER MD)
;       (POPJ-EQUAL M-TEM A-V-NIL)
;;Is this cell "forwarded" with an EVCP in its car?
;       ((VMA-START-READ) MD)
;       (CHECK-PAGE-READ)
;       ((M-TEM) Q-DATA-TYPE READ-MEMORY-DATA)
;       (POPJ-NOT-EQUAL M-TEM (A-CONSTANT (EVAL DTP-EXTERNAL-VALUE-CELL-POINTER)))
;;Else compute the forwarded CDR, and store it back.
;       ((M-TEM) VMA)
;       ((MD) Q-POINTER MD A-TEM)
;       ((VMA-START-WRITE) M-A)
;       (CHECK-PAGE-WRITE)
;       (gc-write-test-volatility-stack-closure-copy)
;;Do the same thing to the next cell (the forwarded CDR).
;       (JUMP SNAP-EVCPS-OUT-OF-HEAP-ENVIRONMENT-COPY)

SNAP-EVCPS-OUT-OF-HEAP-ENVIRONMENT-COPY
     ;MD is a cdr of the copied stack env,
     ;VMA is a pointer to that cdr so we can snap out evcps.
  ((md) q-typed-pointer md)
     ;Quit when we reach the end of the list.
  (popj-equal md a-v-nil)
     ;Error check, only should see dtp-list at this point.
  (check-data-type-call-not-equal md m-tem dtp-list illop)
     ;save old vma and md in case we have to write.
  ((pdl-push) vma)
  ((pdl-push) md)
     ;Read the car of the next pair.
  ((vma-start-read) md)
  (check-page-read)
     ;If evcp, we snap through
     ;If list, we cdr.
     ;Otherwise, it is either an empty environment (T) or we are confused.
     ;Drop through if T.
  (jump-data-type-equal md (a-constant
                              (byte-value q-data-type dtp-external-value-cell-pointer))
                  snap-evcps-out-of-heap-environment-copy-snap-evcp)
  (jump-data-type-equal md (a-constant (byte-value q-data-type dtp-list))
                  snap-evcps-out-of-heap-environment-copy-next-env)
  ((m-tem) q-typed-pointer md)
  (call-not-equal m-tem a-v-true illop)

snap-evcps-out-of-heap-environment-copy-next-env
     ;If it is not forwarded, read the cdr and loop.
  ((vma-start-read) m+1 pdl-pop)
  (check-page-read)
  (jump snap-evcps-out-of-heap-environment-copy pdl-pop)

snap-evcps-out-of-heap-environment-copy-snap-evcp
     ;If it is forwarded, we combine the old cdr-code and data type with
     ;what we read from the car and write it into the old cdr.
  ((m-tem) pdl-pop)
  ((md) dpb md q-pointer a-tem)
  ((vma-start-write) pdl-pop)
  (check-page-write)
  (gc-write-test-volatility-stack-closure-copy)
     ;Okay, so we might have cdr'ed after snapping, but it wont hurt to go around again.
  (jump snap-evcps-out-of-heap-environment-copy)



(begin-comment) zwei wants an open paren in column zero (end-comment)

  (macro-ir-decode (qind4-a stack-closure-disconnect-first *))
STACK-CLOSURE-DISCONNECT-FIRST
     ;Copy a stack closure into the heap and copy the lexical frame also.
  (jump-if-bit-set m-no-stack-closures closure-disconnect-first)
  ((m-t) a-v-nil)

  (macro-ir-decode (qind4-a stack-closure-disconnect *))
STACK-CLOSURE-DISCONNECT
  (jump-if-bit-set m-no-stack-closures closure-disconnect)
     ; Copy the stack closure at local block offset X (contents of low 9 bits of the instruction)
     ; and unshare its pointer to this stack frame.
     ; When first copied, the 4 slots of the closure itself are copied
     ; but still contain a pointer to the lexical frame of the stack frame the closure was in.
     ; Normally this remains there until the frame is exited,
     ; at which time it is replaced by a pointer to a copy of the lexical frame, made in the heap.
     ; This instruction copies the lexical frame immediately.

     ; So that more than one stack closure can be unshared at once, sharing the
     ; same lexical frame,
     ; this instruction expects either a lexical frame copy or NIL in M-T.
     ; If it is NIL, a new lexical frame copy is made if necessary
     ; and stored in M-T on exit.

  ((m-a) macro-ir-adr)
     ;Move the closure and all its kin to the heap.
     ;If it turns out we didn't need to do anything, we return.
  (call stack-closure-clear)
  (popj-equal m-e a-v-nil)

     ;Now M-E has the copied stack closure just cleared.
     ;M-T has NIL if we need to make a copy of the lexical frame
     ;or else has a DTP-LIST pointer to the copy we can use.
  (jump-not-equal m-t a-v-nil stack-closure-disconnect-replace)
     ;Save M-E
  ((pdl-push) m-e)
     ;M-A gets NIL as arg to copy-lexical-frame
     ;If we didn't make have to copy the frame, quit.
  (call-xct-next copy-lexical-frame)
 ((m-a) a-v-nil)
  (jump-equal m-c a-v-true stack-closure-disconnect-empty)

  ((pdl-push) m-c)
     ;Push this frame copy onto the list of all frame copies
     ;made for stack closures copied from this block.
  (call get-stack-closure-frame-copy-list)
     ;Save the pdl-index.  And cons the new frame to the copy list.
  ((pdl-push) dpb pdl-index q-pointer (a-constant (byte-value q-data-type dtp-fix)))
  ((pdl-push) m-c)      ;Args to CONS: the new frame copy,
  ((pdl-push) m-t)      ;and the list of older ones.
  (call xcons)
     ;Restore the pdl-index.  And set the frame copy list to the new version.
  ((pdl-index) pdl-pop)
  ((c-pdl-buffer-index) m-t)
     ;Restore other regs.  M-T gets pointer to copy of frame.
  ((m-t) pdl-pop)
  ((m-e) pdl-pop)

stack-closure-disconnect-replace
     ;Take the CADR of the heap version of the closure.  This is the stack version of the
     ;lexical frame.
  ((vma-start-read) add m-e (a-constant 1))
  (check-page-read)
  (dispatch transport md)
  ((vma-start-read) md)
  (check-page-read)
  (dispatch transport md)
     ;Replace it with the heap version of the frame, preserve the cdr-code.
  ((m-1) md)
  ((md-start-write) dpb m-t q-typed-pointer a-1)
  (check-page-write)
  (gc-write-test-volatility-stack-closure-copy)
  (popj)

stack-closure-disconnect-empty
     ;This is easy, just restore M-E.
  (popj-after-next (m-e) pdl-pop)
  (no-op)



COPY-LEXICAL-FRAME
     ;Make a copy of the lexical-frame.
     ;If M-A is NIL, we just copy the EVCPs in the stack-consed copy.  This is for unsharing
     ;of some lexical variables.
     ;If M-A is not NIL, we snap the evcps.  This is for when we exit the stack frame.
     ;On return, M-C has the copy.  M-J has the pdl index of the word that holds the original.
     ;Except: if the vector in this frame is empty (that is, it is T) then M-J isn't set up.

     ;Make PDL-INDEX point to dtp-list pointer to lexical frame on stack.
  (call get-stack-closure-frame-copy-list)
  ((pdl-index) sub pdl-index (a-constant 1))
     ;If it is T, we are done.
  (jump-equal c-pdl-buffer-index a-v-true copy-lexical-frame-empty)
     ;Save m-a.
  ((pdl-push) m-a)
     ;Calculate size of lexical-frame in M-B
  ((pdl-push m-k) dpb c-pdl-buffer-index q-pointer
                  (a-constant (byte-value q-data-type dtp-fix)))
  (call get-pdl-buffer-index)   ;Convert address in M-K to pdl index in M-K.
  ((m-b) sub pdl-index a-k)
  ((m-b) pdl-buffer-address-mask m-b)

     ;Allocate that many cells + 1 in list storage.
     ;Note that this is different from the old way of doing it.  This is for
     ;compatability with uc-closure which expects an extra cell before the
     ;environment.  We put in a nil in that cell.
  ((pdl-push) dpb m-b q-pointer (a-constant (byte-value q-data-type dtp-fix)))
  ((m-b) add m-b (a-constant 1))
  (call-xct-next allocate-list-storage)
 ((m-s) dpb m-zero q-all-but-typed-pointer a-background-cons-area)

  ((m-tem) a-v-nil)
  ((md) dpb m-tem q-typed-pointer (a-constant (byte-value q-cdr-code cdr-next)))
  ((vma-start-write) m-t)
  (check-page-write)
  (gc-write-test)

     ;Restore some variables.
  ((m-b) q-pointer pdl-pop) ;Holds count.
  ((m-k) pdl-pop)
  ((m-a) pdl-pop)

     ;Put the copy in M-C.
  ((m-c) dpb m-t q-pointer (a-constant (byte-value q-data-type dtp-list)))
  ((m-c) add m-c (a-constant 1))
     ;Setup vma to point to one before the newly consed list.
  ((vma) m-t)
  (call load-pdl-buffer-index)

     ;M-J will hold scan pointer, decide which loop to go to on the basis of m-a.
  (jump-not-equal-xct-next m-a a-v-nil copy-lexical-frame-and-snap-loop)
 ((m-j) pdl-index)

copy-lexical-frame-loop
     ;Fill the copy with forwarding pointers to the stack frame.
     ;VMA advances through the copy while M-J, a pdl index, advances through the lexical frame.
     ;Count is held in M-B
  ((pdl-index) m-j)
     ;Read original.
  ((md) c-pdl-buffer-index)
     ;Write next location in copy.
  ((vma-start-write) add vma (a-constant 1))
  (check-page-write)
  (gc-write-test-volatility-stack-closure-copy) ;no stack closures allowed
     ;Bump M-J, decrement count in M-B.
  ((m-j) add m-j (a-constant 1))
  (jump-greater-than-xct-next m-b (a-constant 1) copy-lexical-frame-loop)
 ((m-b) sub m-b (a-constant 1))
  (popj)

copy-lexical-frame-and-snap-loop
     ;Fill the copy with actual values of variables.
     ;VMA advances through the copy while M-J, a pdl index, advances through the lexical frame.
     ;Count is held in M-B
  ((pdl-index) m-j)
     ;Read original.
  ((m-k) c-pdl-buffer-index)
     ;M-K has a forwarding pointer to a stack frame slot.
     ;It also has the desired cdr-code.
     ;Load up the pdl index with the pdl version
  (call load-pdl-buffer-index)
     ;Read indirect.
  ((md) dpb c-pdl-buffer-index q-typed-pointer a-k)
     ;Write into copy.
  ((vma-start-write) add vma (a-constant 1))
  (check-page-write)
     ;Bump M-J, decrement count in M-B.
  (gc-write-test)  ;***
  ((m-j) add m-j (a-constant 1))
  (jump-greater-than-xct-next m-b (a-constant 1) copy-lexical-frame-and-snap-loop)
 ((m-b) sub m-b (a-constant 1))
  (popj)

copy-lexical-frame-empty
     ;It is easy to copy T.
  ((m-c) a-v-true)
  (popj)



STACK-CLOSURE-CLEAR
     ;Although it is allowed to make stack closures in the current stack frame, it is
     ;sometimes desirable to forward one into the heap.  Stack closure clear forwards the
     ;closure and makes sure that there are no pointers in the frame of type dtp-stack-closure
     ;to the closure.

     ;; M-A specifies the local block offset of the stack closure block to check.
     ;; The copy itself is returned in M-E, or NIL if no copy had to be made.
  ((m-e) a-v-nil)
  ((m-k pdl-index) add m-a a-localp)
     ;If the stack closure is not set up, no need to copy
  (popj-equal c-pdl-buffer-index a-v-nil)
  (call convert-pdl-buffer-address)
     ;Any pointer to the closure in question will be eq to M-B
  ((m-b) dpb m-k q-pointer (a-constant (byte-value q-data-type dtp-stack-closure)))
     ;Scan quickly down the frame and see if anything is pointing to the closure.
     ; Save PDL-POINTER in M-C so we can restore it later in all paths.
  ((m-c) pdl-pointer)

stack-closure-clear-scan-frame-fast
  ((m-1) q-typed-pointer pdl-pop)
  (jump-not-equal-xct-next pdl-pointer a-ap stack-closure-clear-scan-frame-fast)
  (jump-equal m-1 a-b stack-closure-clear-slow)

     ;We win if we drop through, no pointers.
     ;This code needs an explanation.  Two situations may occur here.  If there is an evcp
     ;pointer in the car of the closure we are clearing, we make a dtp-closure to the copy
     ;in the heap.  If not, there are no pointers to the closure anywhere, so we discard it
     ;and return nil.  In either case, we smash the stack copy.
  ((pdl-pointer) m-c)
     ;Make pointer to forwarded copy in case we will need it, we may be making an garbage
     ;pointer here, but we will smash it later if this is the case.
  ((m-e) dpb c-pdl-buffer-index q-pointer
             (a-constant (byte-value q-data-type dtp-closure)))
     ;M-1 gets data type.
  ((m-1) q-data-type c-pdl-buffer-index)
     ;Smash the old stack closure.
  ((c-pdl-buffer-index) a-v-nil)
     ;If the pointer was good, keep it, otherwise, throw it away
  (popj-after-next popj-equal m-1 (a-constant (eval dtp-external-value-cell-pointer)))
 ((m-e) a-v-nil)

stack-closure-clear-slow
     ;We lost, there are pointers to the stack closure.
     ; Forward it into heap if not already done.
  ((pdl-pointer) m-c)
  ((md) q-typed-pointer c-pdl-buffer-index)
     ;Check the data type, if already forwarded, don't bother copying.
  ((m-1) q-data-type md)
  (jump-equal m-1 (a-constant (eval dtp-external-value-cell-pointer))
              stack-closure-clear-already-copied)
  ((vma) m-b)
  (call stack-closure-copy)

stack-closure-clear-already-copied
     ; Now in either case the address of the copy is in MD.  Make a pointer with dtp-closure
     ; to the copy to replace all versions we find in the frame.
  ((m-e) dpb md q-pointer (a-constant (byte-value q-data-type dtp-closure)))
     ;; Save PDL-POINTER in M-C so we can restore it later in all paths.
  ((m-c) pdl-pointer)
     ; Replace each pointer to the original stack closure (in M-B)
     ; with an ordinary closure pointing to the copy (in M-E).

stack-closure-clear-scan-replace
  ((m-1) q-typed-pointer pdl-pop)
  (jump-not-equal-xct-next pdl-pointer a-ap stack-closure-clear-scan-replace)
  (call-equal m-1 a-b stack-closure-clear-found)
     ;Restore M-C
  ((pdl-pointer) m-c)
     ;Smash the stack closure and return.
  (popj-after-next
   (pdl-index) add m-a a-localp)
 ((c-pdl-buffer-index) a-v-nil)

stack-closure-clear-found
     ;Write the dtp-closure over the dtp-stack-closure and return
  ((pdl-index) add pdl-pointer (a-constant 1))
  (popj-after-next (m-1) c-pdl-buffer-index)
 ((c-pdl-buffer-index) dpb m-e q-typed-pointer a-1)



        (macro-ir-decode (qind4-b stack-closure-unshare *))
STACK-CLOSURE-UNSHARE
  (jump-if-bit-set m-no-stack-closures closure-unshare)
     ;Unshare a local variable
     ;in all copies (made by STACK-CLOSURE-DISCONNECT) of this frame's lexical frame.
     ;The address field of the instruction is a 9-bit number
     ;which is this variable's index in the lexical frame.  We do this as follows:
     ;It is assumed that we have made a copy of the stack-consed lexical frame and pushed it
     ;onto the list of lexical frame copies.  In the list of frame copies, the slots in the frame
     ;point with evcps to the locals and args of the frame.  In order to unshare a variable, we
     ;snap the evcp on the first frame in the list and then walk down the list and change the
     ;evcp's in their slots to point to the copy in the first slot.  If we find something already
     ;snapped in one of the lexical frames on the list, we do not want to share with it, so we
     ;quit.

     ; This instruction is never used in a frame whose lexical frame is T (empty).

  (call get-stack-closure-frame-copy-list)
     ;If nobody already shares it, we are done.
  (popj-equal m-t a-v-nil)
     ;M-T has list of lexical frame copies to unshare.
     ;M-J has the lexical frame of this frame.
     ;Calculate M-K gets the evcp in the slot we are unsharing.
  ((pdl-index) sub pdl-index (a-constant 1))
  ((m-b) macro-ir-adr)
     ;Find the slot.
  ((m-k) add c-pdl-buffer-index a-b)
  (call load-pdl-buffer-index)
     ;Read what's there.
  ((m-k) q-typed-pointer c-pdl-buffer-index)
  (call load-pdl-buffer-index)

     ;M-C gets the current value of the local.
  ((m-c) q-typed-pointer c-pdl-buffer-index)
  ((m-1) m-zero)

stack-closure-unshare-forward-to-copy
     ;M-K has an evcp -> the stack slot for the local we are unsharing.
     ;M-C has what to store in place of any evcps pointing to this local.
     ;M-1 is zero if we have not yet found an evcp pointing to this local.
     ;M-B has the index of this local's slot in the lexical frame, and in copies of it.
     ;M-T has the list of all lexical frame copies made in this frame.
     ;Examine each element of the list.
     ;Note that all the ones we need to unforward
     ;must be more recent than the ones we don't need to unforward,
     ;so we can exit the first time we find one already unforwarded.
     ;If we hit the end of the list, we are done.
     ;The first time around this loop, we write the snapped value and create an evcp to
     ;the snapped value to write on subsequent loops.

  (popj-equal m-t a-v-nil)
     ;This spreads a cons into M-A (gets car) and M-T (gets cdr)
  (call carcdr-no-sb)
     ;Read the slot in the lexical frame.
  ((vma-start-read) add m-a a-b)
  (check-page-read)
  ((m-2) q-typed-pointer md)
     ;If it is not an evcp, we are done, it is unshared.
  (popj-not-equal m-2 a-k)
     ;Otherwise, make it be an evcp with the right cdr codes to the copy in the
     ;first frame.
  ((m-2) md)
  ((md-start-write) dpb m-c q-typed-pointer a-2)
  (check-page-write)
  (gc-write-test-volatility)

     ;If we just wrote the value, make up an evcp to the value to use from now on.
  (jump-not-equal m-1 a-zero stack-closure-unshare-forward-to-copy)
     ;Flag in M-1 tells whether this is the first iteration.
  ((m-1) m-minus-one)
     ;Now, M-C will have an EVCP to the value, not the value itself.
  ((m-c) dpb vma q-pointer
         (a-constant (byte-value q-data-type dtp-external-value-cell-pointer)))
  (jump stack-closure-unshare-forward-to-copy)



GET-STACK-CLOSURE-FRAME-COPY-LIST
     ;; Return in M-T the list of all copies of this stack frame
     ;; made by STACK-CLOSURE-DISCONNECT for copies of stack closures.
     ;; This list lives in the last cell of the frame's local block.
     ;; Also leaves the PDL-INDEX pointing to that slot.
; ((PDL-INDEX) M-AP)
; ((VMA-START-READ) ADD C-PDL-BUFFER-INDEX (A-CONSTANT (EVAL %FEFHI-MISC)))
     ;Offset by number of locals.
  ((vma-start-read) add m-fef (a-constant (eval %fefhi-misc)))
  (check-page-read)
  ((pdl-index) (lisp-byte %%fefhi-ms-local-block-length) read-memory-data)
     ;Then back to the last local.
  ((m-t) add m-minus-one a-localp)
  (popj-after-next
   (pdl-index) add pdl-index a-t)
 ((m-t) c-pdl-buffer-index)



STACK-CLOSURE-UNSHARE-ALL
     ;Move the lexical frame into the heap and snap all the evcp's.  Make all lexical frames
     ;share with this one.  This is done so we can pop the stack version.  M-J contains the
     ;copy (all snapped) that we are forwarding to.
     ; Called from QMEX1-COPY as part of exiting a frame in which stack closures have been made
     ; (but not called if the frame's lexical frame is empty).
     ; Preserves M-C and M-D.

  (call get-stack-closure-frame-copy-list)
     ;We are in luck if there are no copies.
  (popj-equal m-t a-v-nil)
  ((m-k) m-ap)
  (call convert-pdl-buffer-address)
  ((m-k) dpb m-k q-pointer
         (a-constant (byte-value q-data-type dtp-external-value-cell-pointer)))
  ((pdl-index) sub pdl-index a-ap)
  ((m-e) m+a+1 pdl-index a-k)

stack-closure-unshare-all-scan-copies
     ;M-K has EVCP -> of start of stack frame,
     ;M-E has EVCP -> end of stack frame (first word after end of local block),
     ;M-J has address of the new copy.
     ;M-T has the list of all copies already made.

     ;If we are at the end, we are done.
  (popj-equal m-t a-v-nil)
     ;Otherwise, spread the list m-a gets car, m-t gets cdr.
  (call carcdr-no-sb)
  ((vma) sub m-a (a-constant 1)) ;Setup for loop.

stack-closure-unshare-all-scan-one-copy
     ;Check a slot, if not an evcp to the original, dont forward to the copy.
  ((vma-start-read) add vma (a-constant 1))
  (check-page-read)
  (dispatch transport-no-evcp md)
  ((m-2) q-typed-pointer md)
  ((m-1) q-cdr-code md)
  (jump-less-than m-2 a-k stack-closure-unshare-all-already-unshared)
  (jump-greater-or-equal m-2 a-e stack-closure-unshare-all-already-unshared)
     ;Forward to the copy.
  ((m-2) sub vma a-a) ;Slot offset into M-D
  ((m-2) add m-2 a-j) ;Plus the start of the copy
     ;Install tag and cdr codes and write it out.
  ((md-start-write) selective-deposit md q-all-but-pointer a-2)
  (check-page-write)
  (gc-write-test)  ;***

stack-closure-unshare-all-already-unshared
     ;Check the cdr code to see if we are done with this copy.
  (jump-not-equal m-1 (a-constant (eval cdr-nil)) stack-closure-unshare-all-scan-one-copy)
  (jump stack-closure-unshare-all-scan-copies)

STACK-CLOSURE-PREPARE-TO-POP-STACK-FRAME

  (jump-if-bit-set m-no-stack-closures closure-prepare-to-pop-stack-frame)

     ;Arg M-A true means snap evcp's while you're at it.
  (call-xct-next copy-lexical-frame)
 ((m-a) a-v-true)

;;; Debugging instruction
;;; Theoretically, stack-closure-prepare... won't get called if the frame is T
  (call-equal m-c a-v-true illop)

     ;M-D gets dtp-list pointer to stack version of the lexical frame.
 ((pdl-index) m-j)
 ((m-d) q-typed-pointer pdl-index-indirect)

     ;PDL-INDEX gets number of locals to scan.  Anything between the start of the frame
     ;and the start of the locals.
 ((pdl-index) sub pdl-index a-localp)
     ;save it.
 ((pdl-push) dpb pdl-index q-pointer (a-constant (byte-value q-data-type dtp-list)))
 ((m-j) m-c)
     ;M-D and M-J get original stack closure vector and copy, both with DTP-LIST.
     ;Any copies previously made should forward to this copy rather than to the stack.
     ;Make that so.
  (call stack-closure-unshare-all)
  ((m-b) q-pointer pdl-pop)     ;pop number of locals to scan.
  ((m-k) a-localp)              ;Get pdl index of first local.

QMEX1-FIND-FORWARDS
     ;Find all stack consed environment chains that point to the stack consed lexical
     ;frame and make them point to the copy.
  ((pdl-index) m-k)
  (jump-data-type-not-equal pdl-index-indirect
                (a-constant (byte-value q-data-type dtp-external-value-cell-pointer))
             qmex1-not-forward)
     ;Yes, find where forwarded to,
     ;and if it points at our frame's lexical frame
     ;make it point at the new copy instead.
  ((vma-start-read) pdl-index-indirect)
  (check-page-read)
  (dispatch transport md)                              ;KHS 850602.
  ((m-tem) q-typed-pointer md)
  (jump-not-equal m-tem a-d qmex1-not-forward)
  ((md-start-write) selective-deposit md q-all-but-typed-pointer a-j) ;was DPB
  (check-page-write)
  (gc-write-test) ;850503

QMEX1-NOT-FORWARD
  ((m-b) sub m-b (a-constant 1))
  (jump-greater-than-xct-next m-b a-zero qmex1-find-forwards)
 ((m-k) m+1 m-k)
  (popj)



MAKE-STACK-CONSED-LEXICAL-FRAME

     ; This routine sets up the lexical frame, the slot before it
     ; and the slots after it.  If the slots have already been set up, it
     ; just returns.

     ; We get the list of what to forward to from the fef cell just before
     ; the debugging info.  (two slots before the instructions)
     ; We store a pointer to the first slot of the block we construct
     ; into the next-to-the-last local slot, and return it in M-C.
     ;; Preserves M-I, M-J, M-2.

; ((PDL-INDEX) M-AP)
; ((VMA-START-READ) ADD C-PDL-BUFFER-INDEX (A-CONSTANT (EVAL %FEFHI-MISC)))
     ;Get the start of the fef.
  ((vma-start-read) add m-fef (a-constant (eval %fefhi-misc)))
  (check-page-read)
  (dispatch transport md)
     ;Get number of locals of this function.
  ((pdl-index) (lisp-byte %%fefhi-ms-local-block-length) read-memory-data)
  ((pdl-index) add pdl-index a-localp)
     ;Point to next-to-the-last local slot.
  ((m-d pdl-index) sub pdl-index (a-constant 2))
     ; If next-to-last-local is non-nil, the lexical frame is already
     ; set up.  We just return the pointer in the next-to-last-local in this
     ; case.
  ((m-c) q-typed-pointer c-pdl-buffer-index)
  (popj-not-equal m-c a-v-nil)
     ; We need to set it up.  M-D will point to the next-to-last-slot, M-C
     ; will be used to scan back up the vector.
  ((m-c) m-d)
     ;Mark this stack frame so that tail recursion will not flush it. **unnecessary now?
  ((pdl-index) add m-ap (a-constant (eval %lp-entry-state)))
  ((m-1) pdl-index-indirect)
  ((pdl-index-indirect) dpb m-minus-one (lisp-byte %%lp-ens-unsafe-rest-arg) a-1)
     ;Get the fef cell preceding the debugging info (two cells before the instructions)
  ((vma-start-read) m-fef)
  (check-page-read)   ;No transport; the executing fef can't be in oldspace.
  ((m-1) (lisp-byte %%fefh-pc-in-words) md)
  ((m-1) m-a-1 m-1 (a-constant 1)) ;subtract 2.
  ((vma-start-read) add vma a-1)   ;add to fef beginning.
  (check-page-read)
  (dispatch transport md)
  ((vma) q-typed-pointer md)
     ;NIL there in the fef means the lexical frame is supposed to be empty.
  (jump-equal vma a-v-nil make-stack-consed-lexical-frame-empty)
     ;Otherwise it is a compact list, each element specifying one vector element.
     ;M-K will get
     ;  [cdr-next dtp-external-value-cell-pointer <pointer to start of frame>]
     ; we will add it to each offset to get the actual thing to place in the
     ; lexical frame
  ((m-k) m-ap)
  (call convert-pdl-buffer-address)
  ((m-k) dpb m-k q-pointer
         (a-constant (plus (byte-value q-data-type dtp-external-value-cell-pointer)
                           (byte-value q-cdr-code cdr-next))))
  ((pdl-index) a-localp)
  ((pdl-index) sub pdl-index a-ap)
  ((m-b) sub pdl-index (a-constant 1))
     ;; M-B has offset of local block with respect to argument 0.
     ;;  The idea here is that M-K + arg-number + 1 is what to store if an arg
     ;;  and M-K + local-number + M-B + 1 is what to store if a local.  This
     ;;  is why M-B points to just before the local.
     ;; M-K has an evcp pointing to start of stack frame, with CDR-NEXT.
     ;; VMA points into list that specifies locals and args to make forwards to.
     ;;  Each element of this list is a fixnum, either arg number, or local number + sign bit.
     ;; M-C has 1+ pdl slot to store in next.
     ;; M-D has pdl slot in which to store the pointer to the list we are making.

make-stack-consed-lexical-frame-loop
  ((vma-start-read) vma)
  (check-page-read)
  (dispatch transport md)
  (jump-if-bit-clear-xct-next boxed-sign-bit md make-stack-consed-lexical-frame-arg)
 ((m-1) (byte-field 10. 0) md)
  ((m-1) add m-1 a-b) ;Otherwise, it is a local: add the local offset.

make-stack-consed-lexical-frame-arg
  ((m-c pdl-index) sub m-c (a-constant 1))
  ((c-pdl-buffer-index) m+a+1 m-k a-1)
  ((m-1) q-cdr-code md)
     ;The map in the FEF is compact so we test for cdr-nil.
  (jump-not-equal-xct-next m-1 (a-constant (eval cdr-nil))
                           make-stack-consed-lexical-frame-loop)
 ((vma) add vma (a-constant 1))
     ;Now we set the last pointer in the stack-closure-vector to cdr-nil.
  ((pdl-index) sub m-d (a-constant 1))
  ((c-pdl-buffer-index) dpb c-pdl-buffer-index q-typed-pointer
                        (a-constant (byte-value q-cdr-code cdr-nil)))
     ;Set the element before the lexical frame to dtp-list pointing to
     ;the beginning of the frame.
  ((pdl-index) sub m-c (a-constant 1))
  ((c-pdl-buffer-index) dpb m-k q-pointer
                        (a-constant (byte-value q-data-type dtp-list)))
     ;M-C is pdl index of start of lexical frame.  Convert it to memory address.
  ((pdl-index) sub m-c a-ap)
  ((m-c) add pdl-index a-k)
  (popj-after-next
   (pdl-index) m-d)
     ;Write the pointer to the lexical frame in the next-to-last local
     ;cell and return it in M-C.
 ((c-pdl-buffer-index m-c) dpb m-c q-pointer
                           (a-constant (byte-value q-data-type dtp-list)))

make-stack-consed-lexical-frame-empty
     ;; Here when this frame's lexical frame can be empty.
     ;; This happens when this function makes lexical closures
     ;; that refer to outer lexical levels but never refer to any arg or local of this function.
     ;; T is used for an empty lexical frame,
     ;; since NIL is used to mean that the vector has not been set up.
  (popj-after-next
   (pdl-index) m-d)
 ((c-pdl-buffer-index m-c) a-v-true)



(begin-comment) zwei wants an open paren in column zero (end-comment)

    (macro-ir-decode (qind1-a make-stack-closure-top-level *))
MAKE-STACK-CLOSURE-TOP-LEVEL
     ;this one compiled when running in "top-level" function.  Avoids building
     ; up unnecessary crap on A-LEXICAL-ENVIRONMENT.
  (jump-if-bit-set m-no-stack-closures make-closure-top-level)
  (jump-xct-next make-stack-closure-1)
 ((m-b) a-v-nil)

    (macro-ir-decode (qind4-a make-stack-closure *))
MAKE-STACK-CLOSURE
  (jump-if-bit-set m-no-stack-closures make-closure)
  ((m-b) a-lexical-environment)

make-stack-closure-1
     ; The low 9 bits of the MAKE-STACK-CLOSURE instruction specify the
     ; first of the 4 local slots to be used to hold the stack consed
     ; closure.

     ; When we make a stack closure, we may have to set up the
     ; (the lexical frame), the dtp-list pointer to
     ; the top of the stack frame just before the lexical frame, the
     ; list of all copies of the lexical frame, and the pointer to
     ; the lexical frame itself.

     ; To make a stack-closure
     ;The function is popped off the stack.
     ;We push on, in its place, a pointer to the first slot, with DTP-STACK-CLOSURE,
     ;after storing the proper values in the 4 local slots and maybe
     ;initializing everything else.

  ((m-i) q-typed-pointer pdl-pop)
     ;Locate the top of the stack frame.
  ((pdl-buffer-index) add m-ap (a-constant (eval %lp-entry-state)))
  ((m-2) c-pdl-buffer-index)
  ((c-pdl-buffer-index) dpb m-minus-one (lisp-byte %%lp-ens-unsafe-rest-arg) a-2)
     ;Locate the area in the locals where we wish to cons the closure.
  ((m-k) macro-ir-adr)
  ((pdl-index m-k) add m-k a-localp)
  (call convert-pdl-buffer-address)
     ;Make a pointer to it on the stack.
  ((pdl-push m-j) dpb m-k q-pointer (a-constant (byte-value q-data-type dtp-stack-closure)))
     ;Examine first slot; non-NIL means everything already set up.
  ((m-1) q-typed-pointer c-pdl-buffer-index)
  (popj-not-equal m-1 a-v-nil)
  ((pdl-push) m-b)      ;cdr link for lexical environment, eventually
     ;M-C now gets frame's lexical frame (either dtp-list to the
     ;lexical frame, or the symbol T).  Save pdl-index in m-2.
     ;Everything concerning lexical frame copies is set up in this subroutine
     ;if necessary.
  (call-xct-next make-stack-consed-lexical-frame)
 ((m-2) pdl-index)
  ((pdl-index) m-2)

     ;Set up the first slot.  It gets the FEF of the closure.
  ((c-pdl-buffer-index) dpb m-i q-typed-pointer
                        (a-constant (byte-value q-cdr-code cdr-next)))
     ;Set up the second slot; points to third slot, and cdr-nil.  This is
     ;just so stack-closures and regular closures are structured the same.
  ((pdl-buffer-index) m+1 pdl-buffer-index)
  ((m-k) add m-j (a-constant 2))
  ((c-pdl-buffer-index) dpb m-k q-pointer
                        (a-constant (plus (byte-value q-data-type dtp-list)
                                          (byte-value q-cdr-code cdr-nil))))
     ;The third and fourth slot are the environment chain, the car is a pointer
     ;to the current lexical frame, the cdr points to the previous lexical environment.
     ;They make up a cons, so the cdr codes must be set up right.
  ((pdl-buffer-index) m+1 pdl-buffer-index)
  ((c-pdl-buffer-index) dpb m-c q-typed-pointer
                        (a-constant (byte-value q-cdr-code cdr-normal)))
     ;Set up the fourth slot; it's the lexical environment of entry to this frame.
  ((pdl-buffer-index) m+1 pdl-buffer-index)
  ((m-j) a-v-nil)               ;don't leave a stack closure here...
  (popj-after-next
   (m-k) pdl-pop)
 ((c-pdl-buffer-index) dpb m-k q-typed-pointer
                       (a-constant (byte-value q-cdr-code cdr-error)))



;Get and set lexical variables inherited from outer contexts.

XSTORE-IN-HIGHER-CONTEXT
     ;Call load from higher context and store into the
     ;q that the vma points to.
  (misc-inst-entry %store-in-higher-context)
  (call xload-from-higher-context)
  ((m-s) dpb vma q-pointer
         (a-constant (byte-value q-data-type dtp-locative)))
  ((m-t) pdl-pop)
  (jump-xct-next xsetcar1)
 ((m-a) m-t)

XLOCATE-IN-HIGHER-CONTEXT
     ;Just call xload-from-higher-context and put the vma
     ;into M-T with dtp-locative.
  (misc-inst-entry %locate-in-higher-context)
  (call xload-from-higher-context)
  (popj-after-next no-op)
 ((m-t) dpb vma q-pointer
        (a-constant (byte-value q-data-type dtp-locative)))

XLOAD-FROM-HIGHER-CONTEXT
        (misc-inst-entry %load-from-higher-context)
     ;Returns address of slot in VMA as well as value of variable in M-T.
     ;Compute in M-T the address of a local or arg in a higher lexical context.
     ;Pops a word off the stack to specify where to find the local:
     ;  High 12. bits  Number of contexts to go up (0 => immediate higher context)
     ;  Low 12. bits      Slot number in that context.
  ((m-1) (byte-field 12. 12.) pdl-top)
     ;Quick test, if offset = 0, we start looking for the variable.
  (jump-equal-xct-next m-1 a-zero xload-from-higher-context-2)
 ((vma) dpb m-zero q-all-but-pointer a-lexical-environment)

xload-from-higher-context-1
     ;Cdr on down the lexical environment until m-1 = 0.
  (call-xct-next pdl-fetch)
 ((vma) add vma (a-constant 1))
  (dispatch transport md)
  ((vma) q-pointer md)
  (jump-greater-than-xct-next m-1 (a-constant 1) xload-from-higher-context-1)
 ((m-1) sub m-1 (a-constant 1))

xload-from-higher-context-2
     ;Take CAR of the cell we have reached, to get the lexical frame.
     ;M-C gets the index therein.
  (call-xct-next pdl-fetch)
 ((m-c) (byte-field 12. 0) pdl-pop)
  (dispatch transport md)

     ;Access that word in the vector.
  ((vma) add md a-c)
  (call-xct-next pdl-fetch)
 ((vma) q-pointer vma)
     ;Check explicitly for an EVCP there pointing to the pdl buffer.
     ;This is faster than transporting the usual way because we still avoid
     ;going through the page fault handler.
;#+cadr ((M-1) Q-DATA-TYPE MD)
;#+cadr (JUMP-NOT-EQUAL M-1 (A-CONSTANT (EVAL DTP-EXTERNAL-VALUE-CELL-POINTER))
;                           XLOAD-FROM-HIGHER-CONTEXT-3)
;#+lambda(jump-data-type-not-equal md
;                (a-constant (byte-value q-data-type dtp-external-value-cell-pointer))
;          xload-from-higher-context-3)
  (check-data-type-jump-not-equal md m-1 dtp-external-value-cell-pointer
                 xload-from-higher-context-3)
     ;It is an evcp, we have to indirect through it.  Also, it is likely to be in the pdl
     ;buffer, so we do this hack to avoid wasting time in the page fault routines.
  ((m-1) q-pointer md)
     ;see pdl-fetch for description of this hack
  (jump-greater-or-equal m-1 a-qlpdlh xload-from-higher-context-3)
  ((pdl-index m-2) sub m-1 a-pdl-buffer-virtual-address)
  (jump-not-equal pdl-index a-2 xload-from-higher-context-3)

     ;It is an EVCP and does point into the pdl buffer, we don't need to transport
     ;it.
  ((pdl-index) add pdl-index a-pdl-buffer-head)
  (popj-after-next (vma) q-pointer md)
 ((m-t md) q-typed-pointer pdl-index-indirect)  ;may not need to store into MD

xload-from-higher-context-3
     ;If it isn't an evcp or in the pdl buffer, just transport it.
  (dispatch transport md)
  (popj-after-next no-op)
 ((m-t) q-typed-pointer md)

PDL-FETCH
     ;MD gets contents of untyped virtual address in VMA, when likely to be in pdl buffer.
     ;Does not assume that the address is actually in the current regpdl.

     ;this is a clever hack:

     ; If the VMA is less than A-PDL-BUFFER-VIRTUAL-ADDRESS, then the subtraction
     ; will produce a negative number, which will be stored in M-2, but will be
     ; masked to 10. or 11. bits in PDL-INDEX.  Therefore, the following instruction
     ; will jump.

     ; If the VMA is bigger than A-PDL-BUFFER-VIRTUAL-ADDRESS + size-of the PDL-BUFFER
     ; then again, M-2 will contain a number bigger than will fit in PDL-INDEX, so
     ; the jump will happen.

     ; The first jump makes sure the VMA is not just past the end of the PDL buffer array.
     ; This is necessary if the hardware pdl buffer is not very full, and we are
     ; storing into the beginning of the next PDL in memory.

  (jump-greater-or-equal vma a-qlpdlh pdl-fetch-1)
  ((pdl-index m-2) sub vma a-pdl-buffer-virtual-address)
  (jump-not-equal pdl-index a-2 pdl-fetch-1)
  (popj-after-next
   (pdl-index) add pdl-index a-pdl-buffer-head)
 ((md) c-pdl-buffer-index)

pdl-fetch-1
  (popj-after-next (vma-start-read) vma)
 (check-page-read)

))
