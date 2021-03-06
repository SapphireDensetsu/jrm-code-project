﻿using Microcode;
using System;
using System.Diagnostics;
using System.Reflection;
using System.Threading;

namespace Listener
{
    class Listener
    {
        static void ColdLoad ()
        {
            string originalDirectory = System.Environment.CurrentDirectory;
            try {
                // System.Environment.CurrentDirectory = System.Environment.CurrentDirectory + "\\..\\..\\..\\Runtime7\\";
                Channel.Initialize (Console.In, Console.Out);
                Object answer;
                if (true) {
                    String projectRoot = 
                        System.IO.Directory.GetParent (System.Environment.CurrentDirectory).Parent.Parent.FullName;
                    if (System.IO.File.Exists (projectRoot + "\\lib\\runtime\\site.bin")) {
                        Microcode.Interpreter.LibraryPath = projectRoot + "\\lib\\";
                    }
                    else if (System.IO.File.Exists (projectRoot + "\\StagingLib\\Runtime\\site.bin")) {
                        Microcode.Interpreter.LibraryPath = projectRoot + "\\StagingLib\\";
                    }
                    else {
                        Microcode.Interpreter.LibraryPath = projectRoot + "\\BootstrapLib\\";
                        Fasl.EnableOldFasload = true;
                    }
                    System.IO.Directory.SetCurrentDirectory (Microcode.Interpreter.LibraryPath + "runtime\\");
                    Console.WriteLine("{0}", System.Environment.CurrentDirectory);

                    // We don't try to load a band.  It's even slower than loading the fasl files!
                    // Load a band
                    //System.Environment.CurrentDirectory = "C:\\jrm-code-project\\MIT-Scheme\\Runtime\\";
                    //System.Environment.CurrentDirectory = "C:\\mit-scheme\\v7\\src\\runtime\\";
                    try {
                        System.IO.FileStream input = System.IO.File.OpenRead ("C:\\jrm-code-project\\MIT-Scheme\\foo.band");
                        System.Runtime.Serialization.Formatters.Binary.BinaryFormatter bfmt = new System.Runtime.Serialization.Formatters.Binary.BinaryFormatter ();
                        WorldState ws = (WorldState) bfmt.Deserialize (input);
                        ScreenChannel.firstTime = false;
                        answer = Continuation.Initial (ws);
                    }

                    catch (System.IO.FileNotFoundException) {
                        // Cold load the Scheme runtime
                        SCode bootstrap = Fasl.Fasload ("make.bin") as SCode;
                        Microcode.Environment initial = Microcode.Environment.Global;
                        answer = Continuation.Initial (bootstrap, initial);
                    }
                    Console.WriteLine ("Evaluation exited with {0}", answer);
                }
                else {
                    // Tak
                    System.Environment.CurrentDirectory = "C:\\jrm-code-project\\TakTest\\";
                    SCode tak = Fasl.Fasload ("tak.bin") as SCode;
                    Microcode.Environment initial = Microcode.Environment.Global;

                    //for (int i = 0; i < 20; i++) {
                    //    ControlState ctl = new ControlState (tak, initial);
                    //    ctl.expression = tak;
                    //    ctl.closureEnvironment = initial;
                    //    Stopwatch takWatch = Stopwatch.StartNew ();
                    //    object result = null;
                    //    while (ctl.expression.Eval (ref result, ref ctl)) { };
                    //    if (result == Interpreter.CaptureContinuation) throw new NotImplementedException ();
                    //    long ticks = takWatch.ElapsedTicks;
                    //    Console.WriteLine ("Ticks {0}", ticks);

                    //}
                    //Console.WriteLine ("e");

                    for (int i = 0; i < 20; i++) {
                        Control expr = tak;
                        Microcode.Environment env = initial;
                        answer = null;
                        Stopwatch takWatch = Stopwatch.StartNew ();
                        while (expr.EvalStep (out answer, ref expr, ref env)) { };
                        if (answer == Interpreter.UnwindStack) throw new NotImplementedException ();
                        //TakLoop (tak, initial);

                        long ticks = takWatch.ElapsedTicks;
                        Console.WriteLine ("Ticks {0}", ticks);
                    }
                    //Console.WriteLine ("e");
                    //for (int i = 0; i < 20; i++) {
                    //    Stopwatch takWatch1 = Stopwatch.StartNew ();
                    //    PartialResult result = tak.Eval (Microcode.Environment.Global);
                    //    while (result.Continue != null) { result = result.Continue.Step (); }
                    //    if (result.CaptureContinuation != null) throw new NotImplementedException ();
                    //    long ticks = takWatch1.ElapsedTicks;
                    //    Console.WriteLine ("Ticks {0}", ticks);
                    //}
                }

                // Interpreter interpreter = new Interpreter ();
                //PartialResult result = bootstrap.Eval (Microcode.Environment.Global);
                //while (result.Continue != null) { result = result.Continue.Step(); }
                //if (result.CaptureContinuation != null) throw new NotImplementedException ();
                //Console.WriteLine ("Returned with {0}", result.Value);
                //                Termination term = interpreter.Start (bootstrap);
                //                Console.WriteLine (term.Message);
            }
            finally {
                System.Environment.CurrentDirectory = originalDirectory;
            }
        }

        private static void TakLoop (Control tak, Microcode.Environment initial)
        {
            object answer = null;
            while (tak.EvalStep (out answer, ref tak, ref initial)) { };
            if ((int) answer != 7)
                throw new NotImplementedException ();
            return;
        }

        static bool CheckOverflowChecking ()
        {
            int i = 2;
            while (i > 0) {
                try {
                    i += i;
                }
                catch (OverflowException) {
                    return true;
                }
            }
            return false;
        }

        static void Main (string [] args)
        {
            string appName = AppDomain.CurrentDomain.FriendlyName;
            Console.WriteLine ("{0}", appName);
            Debug.Listeners.Add (new TextWriterTraceListener (Console.Out));
            Debug.WriteLine ("DEBUG build");

            Debug.WriteLine (CheckOverflowChecking ()
                ? "Overflow checking is enabled."
                : "Overflow checking is disabled.");

            Primitive.Initialize ();
            FixedObjectsVector.Initialize ();
            ColdLoad ();

            Console.WriteLine ();
            Console.WriteLine ("{0} exits", appName);
        }
    }
}
