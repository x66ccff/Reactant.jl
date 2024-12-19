module TracedRandom

# Implementation based on the following:
# 1. https://github.com/JuliaGPU/CUDA.jl/blob/master/src/random.jl
# 2. https://github.com/JuliaRandom/Random123.jl/blob/master/src/common.jl

using ..Reactant:
    Reactant,
    TracedRArray,
    TracedRNumber,
    TracedRNG,
    AnyTracedRArray,
    Reactant,
    TracedUtils,
    Ops,
    ConcreteRArray
using Random: Random, AbstractRNG

@noinline function make_seed(rng::AbstractRNG=Random.RandomDevice())
    # XXX: We should really be able to call this here. But with our AbsInt it leads to a
    #      segfault. So we'll just call it in the rand! method.
    # return rand(rng, UInt64, 2)
    seed = Array{UInt64}(undef, 2)
    Random.rand!(rng, seed)
    return seed
end

function Random.seed!(rng::TracedRNG, seed::Number)
    if seed isa TracedRNumber
        error("Passing in `TracedRNumber` as a seed is not supported. Please pass in a \
               `TracedRArray` of the appropriate size instead.")
    end

    seed = reinterpret(UInt64, Random.hash_seed(seed))
    seed = if Reactant.within_reactant_interpreter()
        TracedUtils.promote_to(TracedRArray{UInt64,1}, seed[1:length(rng.seed)])
    else
        ConcreteRArray(seed[1:length(rng.seed)])
    end
    return Random.seed!(rng, seed)
end

function Random.seed!(rng::TracedRNG, seed::AbstractArray{<:Integer,1})
    return Random.seed!(rng, UInt64.(seed))
end

function Random.seed!(rng::TracedRNG, seed::AbstractArray{UInt64,1})
    return Random.seed!(rng, TracedUtils.promote_to(TracedRArray{UInt64,1}, seed))
end

function Random.seed!(
    rng::TracedRNG, seed::Union{ConcreteRArray{UInt64,1},TracedRArray{UInt64,1}}
)
    rng.seed = seed
    return rng
end

@noinline TracedRNG() = TracedRNG(ConcreteRArray(make_seed()))
@noinline TracedRNG(seed::ConcreteRArray{UInt64,1}) = TracedRNG(seed, "DEFAULT")

@noinline function default_rng()
    Reactant.within_reactant_interpreter() || return TracedRNG()
    return TracedRNG(TracedUtils.promote_to(TracedRArray{UInt64,1}, make_seed()), "DEFAULT")
end

@noinline rng_algorithm(rng::TracedRNG) = rng.algorithm
@noinline rng_algorithm(::AbstractRNG) = "DEFAULT"

@noinline function internal_overload_rand!(
    rng::TracedRNG, A::AnyTracedRArray{T,N}
) where {T,N}
    length(A) == 0 && return A
    res = Ops.rng_bit_generator(T, rng.seed, [size(A)...]; rng.algorithm)
    rng.seed = res.output_state
    TracedUtils.set_mlir_data!(A, res.output.mlir_data)
    return A
end

@noinline function internal_overload_randn!(
    rng::TracedRNG, A::AnyTracedRArray{T,N}
) where {T,N}
    length(A) == 0 && return A
    res = Ops.randn(T, rng.seed, [size(A)...]; rng.algorithm)
    rng.seed = res.output_state
    TracedUtils.set_mlir_data!(A, res.output.mlir_data)
    return A
end

@noinline function internal_overload_randexp!(
    rng::TracedRNG, A::AnyTracedRArray{T,N}
) where {T,N}
    length(A) == 0 && return A
    res = Ops.randexp(T, rng.seed, [size(A)...]; rng.algorithm)
    rng.seed = res.output_state
    TracedUtils.set_mlir_data!(A, res.output.mlir_data)
    return A
end

for randfun in (:rand, :randn, :randexp)
    randfun! = Symbol(randfun, :!)
    overload_randfun = Symbol(:internal_overload_, randfun)
    overload_randfun! = Symbol(:internal_overload_, randfun!)

    @eval begin
        @noinline function $(overload_randfun)(
            rng::TracedRNG, ::Type{T}, dims::Dims
        ) where {T}
            return $(overload_randfun!)(
                rng, TracedRArray{T,length(dims)}((), nothing, dims)
            )
        end

        @noinline function $(overload_randfun)(rng::TracedRNG, dims::Dims)
            return $(overload_randfun)(rng, Float64, dims)
        end

        @noinline function $(overload_randfun)(
            rng::TracedRNG, dim1::Integer, dims::Integer...
        )
            return $(overload_randfun)(rng, Dims((dim1, dims...)))
        end

        @noinline function $(overload_randfun)(
            rng::TracedRNG, ::Type{T}, dim1::Integer, dims::Integer...
        ) where {T}
            return $(overload_randfun)(rng, T, Dims((dim1, dims...)))
        end

        @noinline function $(overload_randfun!)(A::AnyTracedRArray)
            return $(overload_randfun!)(default_rng(), A)
        end

        # scalars
        @noinline function $(overload_randfun)(rng::TracedRNG, ::Type{T}=Float64) where {T}
            A = TracedUtils.promote_to(TracedRArray{T,0}, fill(T(0)))
            $(overload_randfun!)(rng, A)
            return TracedRNumber{T}((), A.mlir_data)
        end
    end
end

# call from overlay-ed variants. we write this with 2 tiers -- overload_* and
# internal_overload_* -- to avoid method ambiguities
for randfun in (:rand, :randn, :randexp, :rand!, :randn!, :randexp!)
    overload_randfun = Symbol(:overload_, randfun)
    internal_overload_randfun = Symbol(:internal_overload_, randfun)
    @eval begin
        @noinline function $(overload_randfun)(rng::AbstractRNG, args...)
            rng = TracedRNG(
                TracedUtils.promote_to(TracedRArray{UInt64,1}, make_seed(rng)),
                rng_algorithm(rng),
            )
            return $(internal_overload_randfun)(rng, args...)
        end

        @noinline function $(overload_randfun)(rng::TracedRNG, args...)
            return $(internal_overload_randfun)(rng, args...)
        end
    end
end

# TODO: At some later point we might want to implement the sampler API as well since it
#       makes all RNG implementation work by default. From the post-optimize IR we need to
#       confirm that the dynamic_update_slice calls are optimized away into a single
#       `stablehlo.rng_bit_generator` call -- confirm that this should be the case based on
#       how the seeding should work?

end