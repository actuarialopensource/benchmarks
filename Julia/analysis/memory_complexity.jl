function generate_memory_complexity_data(model::Model)
  @info "Generating memory complexity benchmarks for model $(nameof(typeof(model)))"
  sizes = [9, 100, 1_000, 10_000, 100_000]
  files = "savings/" .* ["model_point_table_9.csv", "model_point_table_100.csv", "model_point_table_1K.csv", "model_point_table_10K.csv", "model_point_table_100K.csv"]
  ts = 50:50:150
  allocations = zeros(length(files), length(ts))
  for (i, file) in enumerate(files)
    for (j, n) in enumerate(ts)
      policies = policies_from_csv(file)
      allocations[i, j] = (@benchmark CashFlow(Simulation($model, $policies), $n)).memory / 1e6
    end
  end
  MEMORY_RESULTS[model] = (; ts, files, sizes, allocations)
end

function plot_memory_complexity_results(model; folder = images_folder())
  (; ts, sizes, files, allocations) = MEMORY_RESULTS[model]
  colors = Makie.wong_colors()

  fig = Figure(; resolution = (1000, 300))
  ax = Axis(fig[1, 1]; title = "Memory allocations - $(model_title(model)) model", xlabel = "Number of time steps", ylabel = "Allocations (MB)", yscale = log10, xticks = ts)
  ls = [lines!(ax, ts, allocations[i, :]; color = colors[i]) for i in eachindex(sizes)]
  ss = [scatter!(ax, ts, allocations[i, :], color = colors[i]; marker = :x) for i in eachindex(sizes)]
  Legend(fig[1, 2], reverse(collect(collect.(zip(ls, ss)))), "n = " .* reverse(string.(sizes)))
  file = joinpath(folder, "memory_complexity_variable_duration_$(model_string(model)).png")
  @info "Saving plot at $file"
  save(file, fig)

  fig = Figure(; resolution = (1000, 300))
  ax = Axis(fig[1, 1]; title = "Memory allocations - $(model_title(model)) model ($(maximum(ts)) timesteps)", xlabel = "Model size", ylabel = "Allocations (MB)", xscale = log10, yscale = log10)
  lines!(ax, sizes, allocations[:, end]; color = colors[1])
  scatter!(ax, sizes, allocations[:, end]; color = colors[1], marker = :x)
  file = joinpath(folder, "memory_complexity_static_duration_$(model_string(model)).png")
  @info "Saving plot at $file"
  save(file, fig)
end

function memory_complexity_benchmarks(model::Model; folder = images_folder())
  !haskey(MEMORY_RESULTS, model) && generate_memory_complexity_data(model)
  plot_memory_complexity_results(model; folder)
end

memory_complexity_benchmarks(term_life_model[])
memory_complexity_benchmarks(universal_life_model[])
