

```julia
julia> using Reactant

julia> v = []
Any[]

julia> vr = []
Any[]

julia> for i=1:10
       push!(v,rand(1,1000000*2^i))
       end

julia> for i=1:10
       r = Reactant.to_rarray(v[i])
       push!(vr,r)
       end

julia> get_memory_allocated()
16368000000

julia> print_largest_arrays()
Top 5 arrays by memory usage:
1. Type: Float64, Shape: (1, 1024000000), Size: 7812.5 MB, Client: Reactant.XLA.Client(Ptr{Nothing} @0x0000000000ea8a80)
2. Type: Float64, Shape: (1, 512000000), Size: 3906.25 MB, Client: Reactant.XLA.Client(Ptr{Nothing} @0x0000000000ea8a80)
3. Type: Float64, Shape: (1, 256000000), Size: 1953.12 MB, Client: Reactant.XLA.Client(Ptr{Nothing} @0x0000000000ea8a80)
4. Type: Float64, Shape: (1, 128000000), Size: 976.56 MB, Client: Reactant.XLA.Client(Ptr{Nothing} @0x0000000000ea8a80)
5. Type: Float64, Shape: (1, 64000000), Size: 488.28 MB, Client: Reactant.XLA.Client(Ptr{Nothing} @0x0000000000ea8a80)

julia> get_memory_allocated_gb()
15.243887901306152

julia> print_largest_arrays(3)
Top 3 arrays by memory usage:
1. Type: Float64, Shape: (1, 1024000000), Size: 7812.5 MB, Client: Reactant.XLA.Client(Ptr{Nothing} @0x0000000000ea8a80)
2. Type: Float64, Shape: (1, 512000000), Size: 3906.25 MB, Client: Reactant.XLA.Client(Ptr{Nothing} @0x0000000000ea8a80)
3. Type: Float64, Shape: (1, 256000000), Size: 1953.12 MB, Client: Reactant.XLA.Client(Ptr{Nothing} @0x0000000000ea8a80)

```
