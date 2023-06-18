using Benchmarks
import Benchmarks: investment_rate
using BenchmarkTools
using Dates
using Test
using PythonCall

pydir = joinpath(dirname(pkgdir(Benchmarks)), "Python")
os = pyimport("os")
os.chdir(pydir)

mx = pyimport("modelx")
timeit = pyimport("timeit")
pyimport("openpyxl")

!@isdefined(ex4) && (ex4 = mx.read_model("CashValue_ME_EX4"))
proj = ex4.Projection

# !@isdefined(se) && (se = mx.read_model("CashValue_SE").Projection)
# se.model_point_table = proj.model_point_table
# se.point_id = 1

shape(py::Py) = Tuple(pyconvert.(Int, py.shape))
ntimesteps(proj::Py) = pyconvert(Int, proj.max_proj_len())
function timeseries(proj::Py)
  ts = pyconvert(Array, proj.std_norm_rand())
  @assert first(size(ts)) == 1
  ts[1, :]
end
investment_rate(proj::Py) = pyconvert(Array, proj.inv_return_table())[1, :]

@testset "EX4 model" begin
  @testset "Python implementation" begin
    @test ntimesteps(proj) == 121

    @testset "Array shapes" begin
      proj.scen_size = 1000
      # Quickly check that the Python implementation works the way we will assume later on.
      table = proj.model_point_table
      @test length(shape(table)) == 2
      (npoints, nattrs) = shape(table)
      @test (npoints, nattrs) == (9, 10)

      @testset "Monte-Carlo sampling" begin
        # `proj.model_point()` holds all model points duplicated with as many samples as parametrized for the Monte-Carlo estimation.
        nsamples = pyconvert(Int, proj.scen_size)
        @test nsamples == 1000
        points = proj.model_point()
        @test length(points.shape) == 2
        npoints_sampled, nattrs_expanded = points.shape
        @test (npoints_sampled, nattrs_expanded) == (npoints * nsamples, 15)

        # Setting the scenario size to 1 to have only 1 sample for the Monte-Carlo estimation.
        # Since samples are flattened, it has the same effect as "disabling" the Monte-Carlo estimation.
        (; scen_size) = proj
        (npoints_sampled, nattrs_expanded) = proj.model_point().shape
        @test (npoints_sampled, nattrs_expanded) == (npoints, 15)
      end
    end

    @testset "Deterministic generation of random numbers" begin
      proj.scen_size = 1
      arr1 = pyconvert(Matrix{Float64}, proj.std_norm_rand())
      # How many numbers are generated does not depend on the number of timesteps.
      # It only needs to be greater than the number of projected time points.
      n = 242
      @test size(arr1) == (1, n)
      arr2 = pyconvert(Matrix{Float64}, proj.std_norm_rand())
      @test arr1 == arr2
      @test timeseries(proj) == arr1[1, :]
    end
  end

  proj.scen_size = 1

  @testset "Importing policy sets" begin
    policies = policies_from_lifelib("ex4/model_point_table_9.csv")
    policies_py = policies_from_lifelib(proj)
    @test policies == policies_py
  end

  @testset "Investment rates" begin
    ts = timeseries(proj)
    inv_rates_table = pyconvert(Array, proj.inv_return_table())
    # All rates are the same across points.
    # That would be akin to having all account values investing in the same commodities.
    @test allequal(eachslice(inv_rates_table; dims = 1))
    inv_rates_py = inv_rates_table[1, :]
    n = length(inv_rates_py) - 1
    model = EX4(investment_rates = inv_rates_py)
    @test investment_rate.(model, simulation_range(n)) ≈ inv_rates_py
    @test sqrt(sum(x -> x^2, brownian_motion(length(ts)))) ≈ sqrt(sum(x -> x^2, inv_rates_py)) rtol = 0.2
  end

  @testset "Simulation" begin
    policies = [
      PolicySet(Policy(issued_at = Month(-2)), 40),
      PolicySet(Policy(issued_at = Month(0)), 50),
      PolicySet(Policy(issued_at = Month(1)), 50),
    ]
    model = EX4(annual_lapse_rate = 0.01)
    sim = Simulation(model, policies)
    @test length(sim.active_policies) == 1
    @test length(sim.inactive_policies) == 2
    next!(sim)
    @test length(sim.active_policies) == 2
    @test length(sim.inactive_policies) == 1
    n = sum(policy_count, sim.active_policies)
    @test 89 < n < 90
    next!(sim)
    n = sum(policy_count, sim.active_policies)
    @test 139 < n < 140

    policies = policies_from_lifelib()
    sim = Simulation(model, policies)
    # All policies start at month 0, processed in the first simulation step.
    @test isempty(sim.active_policies)
    next!(sim)
    @test length(sim.active_policies) == 100_000
    n = sum(policy_count, sim.active_policies)
    @test n > 4_995_000

    policies = policies_from_lifelib(proj)
    model = EX4(annual_lapse_rate = 0.00)
    sim = Simulation(model, policies)
    simulate!(sim, 12)
    @test sum(policy_count, sim.active_policies) == 900.0

    policies = policies_from_lifelib(proj)
    model = EX4(annual_lapse_rate = 0.00)
    sim = Simulation(model, policies)
    res = Dict(:net_cashflow => 0.0)
    simulate!(sim, 121) do events
      current_net_cashflow = sum(events.account_changes; init = 0.0) do (set, change)
        policy_count(set) * change.net_changes
      end
      # println("Current net cashflow (", length(events.account_changes), " policy sets): ", current_net_cashflow)
      res[:net_cashflow] += current_net_cashflow
    end
    @test_broken res[:net_cashflow] ≈ 399477611.70743275
  end
end

@testset begin
  policies = policies_from_lifelib(proj)
  model = EX4(investment_rates = investment_rate(proj))
  sim = Simulation(model, policies)
  n = ntimesteps(proj) - 1
  pv_net_cashflow = 0.0
  @time simulate!(sim, n) do events
    t = Dates.value(events.time)
    @test policy_count.(events.starts) == filter!(!iszero, pyconvert(Array, proj.pols_new_biz(t)))
    cashflow = CashFlow(events, model)
    @test cashflow.premiums ≈ sum(pyconvert(Array, proj.premiums(t)))
    @test cashflow.investments ≈ sum(pyconvert(Array, proj.inv_income(t)))
    @test cashflow.claims ≈ sum(pyconvert(Array, proj.claims(t)))
    @test cashflow.expenses ≈ sum(pyconvert(Array, proj.expenses(t)))
    @test cashflow.commissions ≈ sum(pyconvert(Array, proj.commissions(t)))
    @test cashflow.account_value_changes ≈ sum(pyconvert(Array, proj.av_change(t)))
    @test cashflow.net ≈ sum(pyconvert(Array, proj.net_cf(t)))
    pv_net_cashflow += cashflow.discounted
  end
  @show pv_net_cashflow
  @show sum(pyconvert(Array, proj.pv_net_cf()))
  sim = Simulation(model, policies)
  @test pv_net_cashflow == CashFlow(sim, model, n).discounted
  @test_broken pv_net_cashflow ≈ proj.pv_net_cf()
end;

@testset "Benchmarks" begin
  proj.clear_cache = 1
  timing = pyconvert(Float64, timeit.timeit("proj.pv_net_cf().sum()"; globals = pydict(; proj), number = 5))
  @test isa(timing, Float64)
  @info "EX4 model (Python): $(round(timing, digits = 3)) seconds"
  proj.clear_cache = 0

  policies = policies_from_lifelib(proj)
  model = EX4(investment_rates = investment_rate(proj))
  n = ntimesteps(proj) - 1
  timing = median(@benchmark CashFlow(sim, model, n).discounted setup = begin
    policies = policies_from_lifelib(proj)
    model = EX4(investment_rates = investment_rate(proj))
    sim = Simulation(model, policies)
  end)
  @info "EX4 model (Julia): $(round(timing.time/1e9, digits = 6)) seconds"

  policies = policies_from_lifelib()
  model = EX4(investment_rates = investment_rate(proj))
  sim = Simulation(model, policies)
  @info "EX4 model (1 million policy sets, Julia)"
  @time CashFlow(sim, model, n)
end
