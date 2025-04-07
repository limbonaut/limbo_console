using Godot;

[Tool]
partial class LimboConsoleAdapterPlugin : EditorPlugin
{
    private const string AutoLoadName = nameof(LimboConsoleAdapter);

    public override void _EnterTree()
    {
        base._EnterTree();
        AddAutoloadSingleton(AutoLoadName,
            "res://addons/limbo_console_cs/LimboConsoleAdapter.cs");
    }

    public override void _ExitTree()
    {
        base._EnterTree();
        RemoveAutoloadSingleton(AutoLoadName);
    }
}
