using namespace System.Windows.Automation
using namespace System.Windows.Automation.Text

$patterns = Get-Type -Assembly UIAComWrapper -Base System.Windows.Automation.BasePattern

Add-Type -Language CSharp -ReferencedAssemblies UIAComWrapper -TypeDefinition @"
using System;
using System.ComponentModel;
using System.Management.Automation;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Windows.Automation;
using System.Runtime.InteropServices;


[AttributeUsage(AttributeTargets.Field | AttributeTargets.Property)]
public class StaticFieldAttribute : ArgumentTransformationAttribute {
    private Type _class;

    public override string ToString() {
        return string.Format("[StaticField(OfClass='{0}')]", OfClass.FullName);
    }

    public override Object Transform( EngineIntrinsics engineIntrinsics, Object inputData) {
        if(inputData is string && !string.IsNullOrEmpty(inputData as string)) {
            System.Reflection.FieldInfo field = _class.GetField(inputData as string, BindingFlags.Static | BindingFlags.Public);
            if(field != null) {
                return field.GetValue(null);
            }
        }
        return inputData;
    }

    public StaticFieldAttribute( Type ofClass ) {
        OfClass = ofClass;
    }

    public Type OfClass {
        get { return _class; }
        set { _class = value; }
    }
}

public static class UIAutomationHelper {

    [DllImport ("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr FindWindow (string lpClassName, string lpWindowName);

    [DllImport ("user32.dll", CharSet = CharSet.Auto)]
    static extern bool AttachThreadInput (int idAttach, int idAttachTo, bool fAttach);

    [DllImport ("user32.dll", CharSet = CharSet.Auto)]
    static extern int GetWindowThreadProcessId (IntPtr hWnd, IntPtr lpdwProcessId);

    [DllImport ("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr SetForegroundWindow (IntPtr hWnd);

    public static AutomationElement RootElement {
        get { return AutomationElement.RootElement; }
    }


    ///<synopsis>Using Win32 to set foreground window because AutomationElement.SetFocus() is unreliable</synopsis>
    public static bool SetForeground(this AutomationElement element)
    {
        if(element == null) {
            throw new ArgumentNullException("element");
        }

        // Get handle to the element
        IntPtr other = FindWindow (null, element.Current.Name);

        // // Get the Process ID for the element we are trying to
        // // set as the foreground element
        // int other_id = GetWindowThreadProcessId (other, IntPtr.Zero);
        //
        // // Get the Process ID for the current process
        // int this_id = GetWindowThreadProcessId (Process.GetCurrentProcess().Handle, IntPtr.Zero);
        //
        // // Attach the current process's input to that of the
        // // given element. We have to do this otherwise the
        // // WM_SETFOCUS message will be ignored by the element.
        // bool success = AttachThreadInput(this_id, other_id, true);

        // Make the Win32 call
        IntPtr previous = SetForegroundWindow(other);

        return !IntPtr.Zero.Equals(previous);
    }
}
"@