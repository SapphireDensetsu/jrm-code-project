﻿using System;
using System.Collections;
using System.Collections.Generic;

namespace Lisp
{
    [CLSCompliant(true)]
    public struct ConsEnumerator : IEnumerator
    {
        Cons head;
        Cons current;
        bool exhausted;

        public ConsEnumerator (Cons head)
        {
            this.head = head;
            this.current = null;
            this.exhausted = false;
        }

        public bool MoveNext ()
        {
            if (current == null) {
                if (exhausted)
                    throw new NotImplementedException ();
                current = head;
                return true;
            }
            else {
                current = (Cons) current.Cdr;
                if (current == null)
                    exhausted = true;
                return !exhausted;
            }
        }

        public void Reset () {
            current = null;
            exhausted = false;
        }

        public object Current
        {
            get
            {
               return current.Car;
            }
        }
    }

    [CLSCompliant(true)]
    public sealed class Cons : ICollection, IEnumerable
    {
        [System.Diagnostics.DebuggerBrowsable (System.Diagnostics.DebuggerBrowsableState.Never)]
        readonly object car;

        [System.Diagnostics.DebuggerBrowsable (System.Diagnostics.DebuggerBrowsableState.Never)]
        readonly object cdr;

        public Cons (object car, object cdr)
        {
            this.car = car;
            this.cdr = cdr;
        }

        public object Car
        {
            [System.Diagnostics.DebuggerStepThrough]
            get
            {
                return this.car;
            }
        }

        public object Cdr
        {
            [System.Diagnostics.DebuggerStepThrough]
            get
            {
                return this.cdr;
            }
        }

        public IEnumerator GetEnumerator ()
        {
            return new ConsEnumerator (this);
        }

        [System.Diagnostics.DebuggerBrowsable (System.Diagnostics.DebuggerBrowsableState.Never)]
        public int Count 
        {
            get
            {
                int length = 1;
                Cons tail = this;
                while (true) {
                    Cons next = tail.cdr as Cons;
                    if (next == null) {
                        if (tail.cdr == null)
                            break;
                        else
                            throw new NotImplementedException ("dotted list");
                    }
                    length += 1;
                    tail = next;
                }
                return length;
            }
        }

        public void CopyTo (Array array)
        {
            throw new NotImplementedException ("CopyTo");
        }

        public void CopyTo (Array array, int arrayIndex)
        {
            throw new NotImplementedException ("CopyTo");
        }


        public void CopyTo (int index, Array array, int arrayIndex, int count)
        {
            throw new NotImplementedException ("CopyTo");
        }

        [System.Diagnostics.DebuggerBrowsable (System.Diagnostics.DebuggerBrowsableState.Never)]
        public bool IsSynchronized
        {
            get
            {
                return false;
            }
        }

        [System.Diagnostics.DebuggerBrowsable (System.Diagnostics.DebuggerBrowsableState.Never)]
        public object SyncRoot
        {
            get
            {
                return this.car;
            }
        }

        public static Cons SubvectorToList (object [] vector, int start, int limit)
        {
            if (vector == null) {
                if (start == limit)
                    return null;
                throw new ArgumentNullException ("vector");
            }
              
            Cons answer = null;
            int count = 1;
            for (int i = start; i < limit; i++) {
                answer = new Cons (vector [limit - count], answer);
                count += 1;
            }
            return answer;
        }
    }

    public struct ConsListEnumerator<T> : IEnumerator<T>
    {
        ConsList<T> head;
        ConsList<T> current;
        bool exhausted;

        public ConsListEnumerator (ConsList<T> head)
        {
            this.head = head;
            this.current = null;
            this.exhausted = false;
        }

        public void Dispose () {
        }

        public bool MoveNext ()
        {
            if (current == null) {
                if (exhausted)
                    throw new NotImplementedException ();
                current = head;
                return true;
            }
            else {
                current = current.Cdr;
                if (current == null)
                    exhausted = true;
                return !exhausted;
            }
        }

        public void Reset ()
        {
            current = null;
            exhausted = false;
        }

        public T Current
        {
            get
            {
                return current.Car;
            }
        }

        object IEnumerator.Current
        {
            get
            {
                return current.Car;
            }
        }
    }

    // A linked list of cons cells.
    public sealed class ConsList<T> : ICollection<T>, IEnumerable<T>, IEnumerable
    {
        [System.Diagnostics.DebuggerBrowsable (System.Diagnostics.DebuggerBrowsableState.Never)]
        readonly T car;

        [System.Diagnostics.DebuggerBrowsable (System.Diagnostics.DebuggerBrowsableState.Never)]
        readonly ConsList<T> cdr;

        public ConsList (T car, ConsList<T> cdr)
        {
            this.car = car;
            this.cdr = cdr;
        }

        public T Car
        {
            [System.Diagnostics.DebuggerStepThrough]
            get
            {
                return this.car;
            }
        }

        public ConsList<T> Cdr
        {
            [System.Diagnostics.DebuggerStepThrough]
            get
            {
                return this.cdr;
            }
        }

        void ICollection<T>.Add (T thing)
        {
            throw new NotSupportedException ();
        }

        void ICollection<T>.Clear ()
        {
            throw new NotSupportedException ();
        }

        bool ICollection<T>.Contains (T thing)
        {
            throw new NotSupportedException ();
        }

        void ICollection<T>.CopyTo (T[] array, int arrayIndex)
        {
            throw new NotImplementedException ("CopyTo");
        }

        bool ICollection<T>.Remove (T thing)
        {
            throw new NotSupportedException ();
        }
        int ICollection<T>.Count
        {
            get
            {
                int length = 1;
                ConsList<T> tail = this;
                while (true) {
                    ConsList<T> next = tail.cdr;
                    if (next == null) {
                        if (tail.cdr == null)
                            break;
                        else
                            throw new NotImplementedException ("dotted list");
                    }
                    length += 1;
                    tail = next;
                }
                return length;
            }
        }
        bool ICollection<T>.IsReadOnly 
        {
            get
            {
                return true;
            }
        }

        public IEnumerator<T> GetEnumerator()
        {
            return new ConsListEnumerator<T> (this);
        }

        IEnumerator IEnumerable.GetEnumerator ()
        {
            throw new NotImplementedException();
        }

        IEnumerator<T> IEnumerable<T>.GetEnumerator ()
        {
            throw new NotImplementedException();
        }
    }
}