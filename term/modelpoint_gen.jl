using DataFrames
using CSV

# This is the GLM table
rga_2014 = (
    intercept=3.2460468406,
    duration=[log(0.05), 0.0, log(0.2)],
    duration_levels=["<10", "10", ">10"],
    issueage=0.1620764522,
    issueage²=-0.0006419533,
    logissueage=-2.7246684047,
    riskclass=[0.0, 0.0342716521, 0.1204694398],
    riskclass_levels=["Super-Pref NS", "NS", "SM"],
    faceamount=[0.0, 0.3153176726, 0.3436644806, 0.3651595476, 0.3645073212],
    faceamount_levels=["<50k", "50k-99k", "100k-249k", "250k-999k", "1m+"],
    premiummode=[0.0, -0.0324429782, -0.2754860904],
    premiummode_levels=["Annual", "Semi/Quarterly", "Monthly"],
    premiumjump=[0.0, 1.1346066041, 1.4915714326, 1.8259985157, 2.0823058090, 2.1180488165, 2.1759679756, 2.2456634786, 2.3042436895, 2.3424735883, 2.3845090119, 2.3560022176],
    premiumjump_issueage_interaction=[0.0, -0.0224086364, -0.0258942527, -0.0304205710, -0.0338345132, -0.0338073701, -0.0347925252, -0.0356704787, -0.0361533190, -0.0366500058, -0.0368730873, -0.0360120152],
    premiumjump_levels=["≤2.0", "2.01-3.0", "3.01-4.0", "4.01-5.0", "5.01-6.0", "6.01-7.0", "7.01-8.0", "8.01-10.0", "10.01-12.0", "12.01-16.0", "16.01-20.0", "20.01+"],
)

# Try to use all the levels from all the factors.
issue_age = 20:60
mortality_tables = 3299:3308
face_amounts = [25000, 50000, 100_000, 250_000, 1_000_000]
premium_modes = ["Annual", "Semiannual", "Quarterly", "Monthly"]
premium_jumps = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 10.0, 12.0, 16.0, 20.0, 22.0]

# Map mortality tables to risk classes, risk classes encoded as riskclass_levels=["Super-Pref NS", "NS", "SM"
mort_to_riskclass_encoded = Dict(
    3299 => 1,
    3300 => 2,
    3301 => 2,
    3302 => 1,
    3303 => 2,
    3304 => 2,
    3305 => 3,
    3306 => 3,
    3307 => 3,
    3308 => 3,
)
mort_to_riskclass = Dict(
    3299 => "Super-Pref NS",
    3300 => "Pref NS",
    3301 => "Residual NS",
    3302 => "Super-Pref NS",
    3303 => "Pref NS",
    3304 => "Residual NS",
    3305 => "Pref SM",
    3306 => "Residual SM",
    3307 => "Pref SM",
    3308 => "Residual SM",
)


modelpoints = DataFrame([
    (
        issue_age=ia,
        mortality_tables=mt,
        riskclass=mort_to_riskclass[mt],
        riskclass_encoded=mort_to_riskclass_encoded[mt],
        face_amounts=fa,
        premium_modes=pm,
        premium_mode_encoded=pm_enc,
        months_between_premiums=months_between_premiums,
        premium_jump=pj,
        premium_jump_encoded=pj_enc
    )
    for (ia, mt, (fa_enc, fa), (pm_enc, pm, months_between_premiums), (pj_enc, pj)) in vec(collect(Iterators.product(
        issue_age,
        mortality_tables,
        enumerate(face_amounts),
        zip([1, 2, 2, 3], premium_modes, [12, 6, 4, 1]),
        enumerate(premium_jumps),
    )))
])

# write modelpoints to csv
CSV.write("modelpoints.csv", modelpoints)