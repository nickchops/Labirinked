config =
{
    debug =
    {
        general = false,
        traceGC = false,
        typeChecking = false,
        assertDialogs = false,

        makePrecompiledLua = false,
        usePrecompiledLua = false, -- may speed up both load and execution time
        useConcatenatedLua = false, -- speeds up *load* times
    }
}
