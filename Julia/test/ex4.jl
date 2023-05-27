using Benchmarks
using Dates
using Test

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
  @test n > 5_000_000

  policies = policies_from_lifelib("ex4/model_point_table_9.csv")
  model = EX4(annual_lapse_rate = 0.00)
  sim = Simulation(model, policies)
  simulate!(sim, 12)
  @test sum(policy_count, sim.active_policies) == 900.0
end;
