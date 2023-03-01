# source code from actuarial open source fork of experience studies package
module ExpFork

using Dates

abstract type ExposurePeriod end

struct Anniversary{T<:DatePeriod} <: ExposurePeriod
    pol_period::T
end

struct AnniversaryCalendar{T<:DatePeriod,U<:DatePeriod} <: ExposurePeriod
    pol_period::T
    cal_period::U
end

struct Calendar{U<:DatePeriod} <: ExposurePeriod
    cal_period::U
end

# make ExposurePeriod broadcastable so that you can broadcast 
Base.Broadcast.broadcastable(ic::ExposurePeriod) = Ref(ic)

"""
get smallest `t` such that `from + t*step > max(from, left_trunc)`
"""
function get_timestep_past(from::Date, left_trunc::Date, step::DatePeriod)
    if from >= left_trunc
        return 1
    end
    t = 1
    while from + t * step <= left_trunc
        t += 1
    end
    return t
end

"""
We create intervals with two pointers. This function helps us find the starting points of the first and second intervals, `cur` and `nxt`. We also return the timestep of the interval starting with `nxt`.
"""
function preprocess_left(
    from::Date,
    step::DatePeriod,
    study_start::Union{Date,Nothing},
    left_partials::Bool,
)
    # deal with nothing case
    left_trunc = isnothing(study_start) ? from : max(from, study_start)
    # find first endpoint
    t = get_timestep_past(from, left_trunc, step)
    # if left_partials == false:
    # from + (t-1) * step == left_trunc means that the first interval is good and need not be skipped.
    if left_partials || (from + (t - 1) * step == left_trunc)
        cur = left_trunc
        nxt = from + t * step
        return cur, nxt, t
    else
        cur = from + t * step
        nxt = from + (t + 1) * step
        return cur, nxt, t + 1
    end
end

"""
If data has problems like `from > to` or `study_start > study_end` throw an error. 
If the policy doesn't overlap with the study period, return false. If there is overlap, return true.
"""
function validate(
    from::Date,
    to::Union{Date,Nothing},
    study_start::Union{Date,Nothing},
    study_end::Date,
)
    # throw errors if inputs are not good
    !isnothing(to) && from > to &&
        throw(DomainError("from=$from argument is a later date than the to=$to argument."))

    !isnothing(study_start) &&
        study_start > study_end &&
        throw(
            DomainError(
                "study_start=$study_start argument is a later date than the study_end=$study_end argument.",
            ),
        )

    # if no overlap return false, if overlap return true
    return (isnothing(study_start) || isnothing(to) || study_start <= to) && (from <= study_end)
end

"""
    exposure(ExposurePeriod,from,to,continued_exposure=false)

Return an array of name tuples `(from=Date,to=Date)` of the exposure periods for the given `ExposurePeriod`s. 

If `continued_exposure` is `true`, then the final `to` date will continue through the end of the final ExposurePeriod. This is useful if you want the decrement of interest is the cause of termination, because then you want a full exposure.


# Example

```julia
julia> using ExperienceAnalysis,Dates

julia> issue = Date(2016, 7, 4)
julia> termination = Date(2020, 1, 17)
julia> basis = ExperienceAnalysis.Anniversary(Year(1))

julia> exposure(basis, issue, termination)
4-element Array{NamedTuple{(:from, :to),Tuple{Date,Date}},1}:
 (from = Date("2016-07-04"), to = Date("2017-07-04"))
 (from = Date("2017-07-04"), to = Date("2018-07-04"))
 (from = Date("2018-07-04"), to = Date("2019-07-04"))
 (from = Date("2019-07-04"), to = Date("2020-01-17"))


"""
function exposure(
    p::Anniversary,
    from::Date,
    to::Union{Date,Nothing},
    continued_exposure::Bool = false;
    study_start::Union{Date,Nothing} = nothing,
    study_end::Date,
    left_partials::Bool = false,
    right_partials::Bool = true,
)::Vector{NamedTuple{(:from, :to, :policy_timestep),Tuple{Date,Date,Int}}}

    result = NamedTuple{(:from, :to, :policy_timestep),Tuple{Date,Date,Int}}[]
    # no overlap
    if !validate(from, to, study_start, study_end)
        return result
    end
    period = p.pol_period
    right_trunc = isnothing(to) ? study_end : min(study_end, to)
    # cur is current interval start, nxt is next interval start, t is timestep for nxt
    cur, nxt, t = preprocess_left(from, period, study_start, left_partials)
    while cur <= right_trunc && (right_partials || (nxt <= study_end + Day(1))) #more rows to fill 
        push!(result, (from = cur, to = nxt - Day(1), policy_timestep = t))
        t += 1
        cur, nxt = nxt, from + t * period
    end

    # If exposure is not continued, it should go at most to right_trunc
    if !continued_exposure && !isempty(result)
        result[end] = (
            from = result[end].from,
            to = min(result[end].to, right_trunc),
            policy_timestep = result[end].policy_timestep,
        )
    end

    return result
end

end