using Godot;
using System.Collections.Generic;

public partial class LimboConsoleAdapter : Node
{
    public static LimboConsoleAdapter Instance { get; private set; }

    public bool Enabled
    {
        get => limboConsoleNode.Get("enabled").AsBool();
        private set => limboConsoleNode.Set("enabled", value);
    }

    public bool IsOpen => limboConsoleNode.Call("is_open").AsBool();

    private Node limboConsoleNode;

    public override void _Ready()
    {
        base._Ready();
        Instance = this;
        limboConsoleNode = GetTree().Root.GetNode("LimboConsole");
    }
    public void OpenConsole()
    {
        limboConsoleNode.Call("open_console");
    }

    public void CloseConsole()
    {
        limboConsoleNode.Call("close_console");
    }

    public void ClearConsole()
    {
        limboConsoleNode.Call("clear_console");
    }

    public void EraseHistory()
    {
        limboConsoleNode.Call("erase_history");
    }

    public void ToggleHistory()
    {
        limboConsoleNode.Call("toggle_history");
    }

    public void ToggleConsole()
    {
        limboConsoleNode.Call("toggle_console");
    }

    public void RegisterCommand(Callable callable, string name = null)
    {
        if (string.IsNullOrEmpty(name))
        {
            limboConsoleNode.Call("register_command", callable);
        }
        else
        {
            limboConsoleNode.Call("register_command", callable, name);
        }
    }

    public void UnregisterCommand(string name)
    {
        limboConsoleNode.Call("unregister_command", name);
    }

    public bool HasCommand(string name)
    {
        return limboConsoleNode.Call("has_command", name).AsBool();
    }

    public IReadOnlyList<string> GetCommandNames(string name)
    {
        return limboConsoleNode.Call("get_command_names", name).AsStringArray();
    }

    public string GetCommandDescription(string name)
    {
        return limboConsoleNode.Call("get_command_description", name).AsString();
    }

    public void AddAlias(string alias, string commandToRun)
    {
        limboConsoleNode.Call("add_alias", alias, commandToRun);
    }

    public void RemoveAlias(string alias)
    {
        limboConsoleNode.Call("remove_alias", alias);
    }

    public bool HasAlias(string name)
    {
        return limboConsoleNode.Call("has_alias", name).AsBool();
    }

    public IReadOnlyList<string> GetAliases()
    {
        return limboConsoleNode.Call("get_aliases").AsStringArray();
    }

    public IReadOnlyList<string> GetAliasArv(string alias)
    {
        return limboConsoleNode.Call("get_alias_argv", alias).AsStringArray();
    }

    public void Info(string message)
    {
        limboConsoleNode.Call("info", message);
    }

    public void Warn(string message)
    {
        limboConsoleNode.Call("warn", message);
    }

    public void Error(string message)
    {
        limboConsoleNode.Call("error", message);
    }

    public void Debug(string message)
    {
        limboConsoleNode.Call("debug", message);
    }

    public void PrintBoxed(string message)
    {
        limboConsoleNode.Call("print_boxed", message);
    }

    public void PrintLine(string message, bool? printToStdOut = null)
    {
        if (printToStdOut.HasValue)
        {
            limboConsoleNode.Call("print_line", message, printToStdOut.Value);
        }
        else
        {
            limboConsoleNode.Call("print_line", message);
        }
    }

    public void ExecuteCommand(string commandLine, bool? silent = null)
    {
        if (silent.HasValue)
        {
            limboConsoleNode.Call("execute_command", commandLine, silent.Value);
        }
        else
        {
            limboConsoleNode.Call("execute_command", commandLine);
        }
    }

    public void ExecuteScript(string file, bool? silent = null)
    {
        if (silent.HasValue)
        {
            limboConsoleNode.Call("execute_script", file, silent.Value);
        }
        else
        {
            limboConsoleNode.Call("execute_script", file);
        }
    }

    public void AddArgumentAutocompleteSource(
        string command, int argument, Callable source)
    {
        limboConsoleNode.Call("add_argument_autocomplete_source",
            command, argument, source);
    }

    public int Usage(string name)
    {
        var result = limboConsoleNode.Call("usage", name).AsInt32();
        if (result != 0)
        {
            GD.PrintErr($"usage: Failed with error code: {result}");
        }
        return result;
    }

    public void AddEvalInput(string name, Variant value)
    {
        limboConsoleNode.Call("add_eval_input", name, value);
    }

    public void RemoveEvalInput(string name)
    {
        limboConsoleNode.Call("remove_eval_input", name);
    }

    public IReadOnlyList<string> GetEvalInputNames()
    {
        return limboConsoleNode.Call("get_eval_input_names").AsStringArray();
    }

    public void SetEvalBaseInstance(GodotObject obj)
    {
        limboConsoleNode.Call("set_eval_base_instance", obj);
    }

    public GodotObject GetEvalBaseInstance()
    {
        return limboConsoleNode.Call("get_eval_base_instance").AsGodotObject();
    }
}
