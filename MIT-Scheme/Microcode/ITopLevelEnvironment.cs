﻿using System.Collections.Generic;

namespace Microcode
{
    interface ITopLevelEnvironment
    {   

        /// <summary>
        /// Returns an IDictionary of the unshadowed top-level bindings.
        /// </summary>
        IDictionary<Symbol, ValueCell> ExportedTopLevelVariables { get; } 
        
        /// <summary>
        /// Invokes one of the specialized Make methods within the
        /// variable. 
        /// </summary>
        /// <param name="variable"></param>
        /// <returns></returns>
        SCode SpecializeVariable (IVariableSpecializer variable);

    }
}
