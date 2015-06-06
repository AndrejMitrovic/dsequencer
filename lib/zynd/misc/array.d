module zynd.misc.array;

import std.array;
import std.range;
import std.stdio;
import std.traits;
import std.typetuple;

// todo: temporary import until allocators get into phobos
import zynd.allocators.region;

// By Philippe Sigaud
template rank(T)
{
    static if (isInputRange!T) // is T a range?
        enum rank = 1 + rank!(ElementType!T); // if yes, recurse
    else // base case, stop there
        enum rank = 0;
}

// By Philippe Sigaud
template BaseElementType(T)
{
    static if (rank!T == 0) // not a range
        static assert(0, T.stringof ~ " is not a range.");
    else static if (rank!T == 1) // simple range
        alias ElementType!T BaseElementType;
    else // at least range of ranges
        alias BaseElementType!(ElementType!(T)) BaseElementType;
}

/// Initialize array with a single element
void initArr(R, E)(R arr, E init)
    if (isArray!R && is(E == BaseElementType!R))
{
    static if (isArray!(ElementType!R))
    {
        foreach (subArr; arr)
            initArr(subArr, init);
    }
    else
    {
        arr[] = init;
    }
}

/// Initialize array with another array
void initArr(R)(R arr, R init)
    if (isArray!R)
{
    static if (isArray!(ElementType!R))
    {
        foreach (subArr, subInit; lockstep(arr, init))
            initArr(subArr, subInit);
    }
    else
    {
        arr[] = init[];
    }
}

/// Return a singly-initialized array, initialized to a single element or to another array's elements
auto initializedArray(T, I...)(I args)
    if ((is(I[0] == T) || is(I[0] == BaseElementType!T)) &&
        allSatisfy!(isIntegral, I[1 .. $]))
{
    auto arr = uninitializedArray!(T)(args[1 .. $]);
    initArr(arr, args[0]);
    return arr;
}

unittest
{
    auto arr2 = initializedArray!(int[][])(1, 2, 2);
    assert(arr2 == [[1, 1], [1, 1]]);
}


unittest
{
    auto arr2 = initializedArray!(int[][])([[1, 2], [3, 4]], 2, 2);
    assert(arr2 == [[1, 2], [3, 4]]);
}

struct Region(T)
{
    RegionAllocator alloc;
    T arr;

    debug version(logging)
    {
        ~this() { writeln("region dtor"); }
    }
}

Region!T regionInitArray(T, I...)(I args)
    if ((is(I[0] == T) || is(I[0] == BaseElementType!T)) &&
        allSatisfy!(isIntegral, I[1 .. $]))
{
    auto alloc = newRegionAllocator;
    auto arr = alloc.uninitializedArray!(T)(args[1 .. $]);
    initArr(arr, args[0]);

    return Region!T(alloc, arr);
}

unittest
{
    auto rgn = regionInitArray!(float[][])(0.0f, 2, 2);
    auto arr = rgn.arr;
    assert(arr == [[0.0f, 0.0f], [0.0f, 0.0f]]);
}

unittest
{
    auto tempArr = [[1, 2], [3, 4]];
    auto rgn = regionInitArray!(int[][])(tempArr, 2, 2);

    tempArr[0][0] = 4;  // verify the new array doesn't point to old one
    auto arr = rgn.arr;
    assert(arr == [[1, 2], [3, 4]]);
}
