Base.@kwdef struct RGA_2014
    intercept::Float64 = 3.2460468406
    duration::Vector{Float64} = [log(0.05), 0.0, log(0.2)]
    duration_levels::Vector{String} = ["<10", "10", ">10"]
    issueage::Float64 = 0.1620764522
    issueage²::Float64 = -0.0006419533
    logissueage::Float64 = -2.7246684047
    riskclass::Vector{Float64} = [0.0, 0.0342716521, 0.1204694398]
    riskclass_levels::Vector{String} = ["Super-Pref NS", "NS", "SM"]
    faceamount::Vector{Float64} = [0.0, 0.3153176726, 0.3436644806, 0.3651595476, 0.3645073212]
    faceamount_levels::Vector{String} = ["<50k", "50k-99k", "100k-249k", "250k-999k", "1m+"]
    premiummode::Vector{Float64} = [0.0, -0.0324429782, -0.2754860904]
    premiummode_levels::Vector{String} = ["Annual", "Semi/Quarterly", "Monthly"]
    premiumjump::Vector{Float64} = [0.0, 1.1346066041, 1.4915714326, 1.8259985157, 2.0823058090, 2.1180488165, 2.1759679756, 2.2456634786, 2.3042436895, 2.3424735883, 2.3845090119, 2.3560022176]
    premiumjump_issueage_interaction::Vector{Float64} = [0.0, -0.0224086364, -0.0258942527, -0.0304205710, -0.0338345132, -0.0338073701, -0.0347925252, -0.0356704787, -0.0361533190, -0.0366500058, -0.0368730873, -0.0360120152]
    premiumjump_levels::Vector{String} = ["≤2.0", "2.01-3.0", "3.01-4.0", "4.01-5.0", "5.01-6.0", "6.01-7.0", "7.01-8.0", "8.01-10.0", "10.01-12.0", "12.01-16.0", "16.01-20.0", "20.01+"]
end

rga = RGA_2014()

struct LapsePredictor
    base_lapse::Vector{Float64}
    duration_adjustments::Vector{Float64}
    function LapsePredictor(
        issue_age::Vector{Int},
        risk_class::Vector{Int},
        face_amount_band::Vector{Int},
        premium_mode::Vector{Int},
        premium_jump_band::Vector{Int},
        rga::RGA_2014=RGA_2014(),
    )
        base_lapse = exp.(
            rga.intercept .+
            rga.issueage .* issue_age +
            rga.issueage² .* issue_age .^ 2 +
            rga.logissueage .* log.(issue_age) +
            rga.riskclass[risk_class] +
            rga.faceamount[face_amount_band] +
            rga.premiummode[premium_mode] +
            rga.premiumjump[premium_jump_band] +
            rga.premiumjump_issueage_interaction[premium_jump_band] .* issue_age
        )
        # no encoding of duration
        duration_adjustments = Array{Float64}(undef, 20)
        for i in 1:20
            if i < 10
                duration_adjustments[i] = exp(rga.duration[1])
            elseif i == 10
                duration_adjustments[i] = exp(rga.duration[2])
            else
                duration_adjustments[i] = exp(rga.duration[3])
            end
        end
        new(base_lapse, duration_adjustments)
    end
end
# separate durational factor from factors not varying by duration, should be faster
function (lp::LapsePredictor)(duration::Int)
    lp.base_lapse .* lp.duration_adjustments[duration]
end

lp = LapsePredictor([45], [2], [4], [1], [8])
@assert lp(10) == [0.9117056261704399] #this is from the RGA report
