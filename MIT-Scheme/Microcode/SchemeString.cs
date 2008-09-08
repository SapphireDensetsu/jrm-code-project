﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Microcode
{
    static class SchemeString
    {
        [SchemePrimitive ("STRING?", 1)]
        public static bool IsString (out object answer, object arg)
        {
            answer = arg is char [];
            return false;
        }

        [SchemePrimitive ("STRING->SYMBOL", 1)]
        public static bool StringToSymbol (ref object result, object arg)
        {
            result = String.Intern (new String ((char []) arg));
            return false;
        }

        [SchemePrimitive ("STRING-ALLOCATE", 1)]
        public static bool StringAllocate (out object answer, object arg)
        {
            answer = new char [(int) arg];
            return false;
        }

        [SchemePrimitive ("STRING-HASH-MOD", 2)]
        public static bool StringHashMod (out object answer, object str, object modulus)
        {
            int tmp = new string ((char []) str).GetHashCode () % (int) modulus;
            if (tmp < 0) tmp += (int) modulus;
            answer = tmp;
            return false;
        }

        [SchemePrimitive ("STRING-LENGTH", 1)]
        public static bool StringLength (out object answer, object arg)
        {
            answer = ((char []) arg).Length;
            return false;
        }

        [SchemePrimitive ("STRING-REF", 2)]
        public static bool StringRef (out object answer, object str, object idx)
        {
            answer = ((char []) str) [(int) idx];
            return false;
        }

        [SchemePrimitive ("STRING-SET!", 3)]
        public static bool StringSet (out object answer, object str, object idx, object val)
        {
            answer = ((char []) str) [(int) idx];
            ((char []) str) [(int) idx] = (char) val;
            return false;
        }

        [SchemePrimitive ("SUBSTRING-MOVE-RIGHT!", 5)]
        public static bool SubstringMoveRight (out object answer, object [] arglist)
        {
            char [] ptr1 = (char []) (arglist [0]);
            int len1 = ptr1.Length;
            int end1 = (int) (arglist [2]);
            int start1 = (int) (arglist [1]);
            char [] ptr2 = (char []) (arglist [3]);
            int len2 = ptr2.Length;
            int start2 = (int) (arglist [4]);
            int length = end1 - start1;
            int end2 = start2 + length;

            int scan1 = end1;
            int scan2 = end2;
            int limit = scan1 - length;
            while (scan1 > limit)
                ptr2 [--scan2] = ptr1 [--scan1];
            answer = Constant.Unspecific;
            return false;
        }

        [SchemePrimitive ("SUBSTRING-MOVE-LEFT!", 5)]
        public static bool SubstringMoveLeft (out object answer, object [] arglist)
        {
            char [] ptr1 = (char []) (arglist [0]);
            int len1 = ptr1.Length;
            int end1 = (int) (arglist [2]);
            int start1 = (int) (arglist [1]);
            char [] ptr2 = (char []) (arglist [3]);
            int len2 = ptr2.Length;
            int start2 = (int) (arglist [4]);
            int length = end1 - start1;
            int end2 = start2 + length;

            int scan1 = start1;
            int scan2 = start2;
            int limit = scan1 + length;
            while (scan1 < limit)
                ptr2 [scan2++] = ptr1 [scan1++];
            answer = Constant.Unspecific;
            return false;
        }

        [SchemePrimitive ("SUBSTRING=?", 6)]
        public static bool IsSubstringEqual (out object answer, object [] arglist)
        {
            char [] left = (char []) (arglist [0]);
            int left_scan = (int) (arglist [1]);
            int left_limit = (int) (arglist [2]);
            char [] right = (char []) (arglist [3]);
            int right_scan = (int) (arglist [4]);
            int right_limit = (int) (arglist [5]);
            if ((left_limit - left_scan) != (right_limit - right_scan)) {
                answer = false;
                return false;
            }
            while (left_scan < left_limit) {
                if (left [left_scan++] != right [right_scan++]) {
                    answer = false;
                    return false;
                }
            }
            answer = (right_scan == right_limit);
            return false;
        }

        [SchemePrimitive ("SUBSTRING-DOWNCASE!", 3)]
        public static bool SubstringDowncase (out object answer, object astr, object astart, object aend)
        {
            char [] str = (char []) astr;
            int start = (int) astart;
            int end = (int) aend;
            int length = (end - start);
            int scan = start;
            while ((length--) > 0) {
                char temp = str [scan];
                str [scan++] = Char.ToLower (temp);
            }
            answer = Constant.Unspecific;
            return false;
        }

        [SchemePrimitive ("SUBSTRING-FIND-NEXT-CHAR-IN-SET", 4)]
        public static bool SubstringFindNextCharInSet (out object answer, object [] arglist)
        {
            char [] str = (char []) (arglist [0]);
            int scan = (int) (arglist [1]);
            int limit = (int) (arglist [2]);
            char [] charset = (char []) (arglist [3]);

            while (scan < limit) {
                if (charset [str [scan++]] != '\0') {
                    answer = scan - 1;
                    return false;
                }
            }
            answer = false;
            return false;
        }
    }
}
