using Benchmarks
using Dates
using Test

policies = policies_from_lifelib()
model = EX4(annual_lapse_rate = 0.01)
sim = Simulation(model, policies)
