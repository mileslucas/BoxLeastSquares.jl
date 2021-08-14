
function make_data(N=500)
    t = rand(rng, Uniform(0, 10), N)
    dy = rand(rng, Uniform(0.005, 0.010), N)
    period = 2.0
    t0 = 0.5
    duration = 0.16
    depth = 0.2
    mask = @. abs((t - t0 + 0.5 * period) % period - 0.5 * period) < 0.5 * duration
    y = @. ifelse(mask, 1 - depth, 1)
    y .+= dy .* randn(rng, N)
    return t, y, dy, (;period, t0, duration, depth)
end


@testset "autoperiod self-consistency" begin
    t, y, dy, params = make_data()
    durations = params.duration .+ range(-0.1, 0.1, length=3)

    period = @inferred autoperiod(t, durations)
    model1 = @inferred BLS(t, y, dy; duration=durations, periods=period)
    model2 = @inferred BLS(t, y, dy; duration=durations)
    @test BoxLeastSquares.power(model1) ≈ BoxLeastSquares.power(model2)

end

@testset "model correctness ($obj)" for obj in [:likelihood, :snr]
    t, y, dy, params = make_data()

    periods = exp.(range(log(params.period) - 0.1, log(params.period) + 0.1, length=1000))

    model = @inferred BLS(t, y, dy; params.duration, periods, objective=obj)
    best_params = BoxLeastSquares.params(model)

    @test best_params.period ≈ params.period atol = 0.01
    @test best_params.t0 ≈ params.t0 atol = 0.01
    @test best_params.duration ≈ params.duration atol = 0.01
    @test best_params.depth ≈ params.depth atol = best_params.depth_err
end

@testset "transit model" begin
    t, y, dy, params = make_data()

    # compute model using linear regression
    A = zeros(length(t), 2)
    dt = @. abs((t - params.t0 + 0.5 * params.period) % params.period - 0.5 * params.period)
    intransit = @. dt < 0.5 * params.duration
    A[.!intransit, 1] .= 1
    A[intransit, 2] .= 1
    w = (A' * (A ./ dy .^2)) \ (A' * (y ./ dy .^2))
    model_true = A * w

    # model = @inferred BoxLeastSquares.model(t, y, dy; params...)
    model = BoxLeastSquares.model(t, y, dy; params...)
    @test model ≈ model_true
end

