using CSV
using Dates
using DataFrames
using PyCall
using TimeZones

"""
Fetch and clean one CPCB daily AQI bulletin.
"""
function fetch_and_process_bulletin(date_to_fetch::Date)
    println("Attempting to fetch AQI bulletin for: ", date_to_fetch)
    tabula = pyimport("tabula")
    url = "https://cpcb.nic.in/upload/Downloads/AQI_Bulletin_$(replace(string(date_to_fetch), "-" => "")).pdf"
    output_path = joinpath(@__DIR__, "data", "$(date_to_fetch).csv")
    mkpath(dirname(output_path))

    try
        tabula.convert_into(url, output_path, lattice=true, output_format="csv", pages="all")
        println("Downloaded: ", url)
    catch e
        println("Skipping $(date_to_fetch): bulletin unavailable or extraction failed. Error: ", e)
        return false
    end

    try
        df = CSV.read(output_path, DataFrame, silencewarnings=true)
        if "S.No" in names(df)
            select!(df, Not(Symbol("S.No")))
        end
        headers = [:city, :level, :index, :pollutant, :stations]
        if length(names(df)) < 5
            error("Unexpected bulletin table structure")
        end
        rename!(df, names(df)[1:5], headers, makeunique=true)

        deleteat!(df, findall(ismissing, df.index))
        deleteat!(df, findall(x -> tryparse(Int, string(x)) === nothing, df.index))

        for r in 1:nrow(df)
            df[r, :city] = titlecase(replace(string(df[r, :city]), "\r" => " ", "_" => " "))
            p_val = ismissing(df[r, :pollutant]) ? "" : string(df[r, :pollutant])
            pollutant_str = ""
            if occursin("3", p_val) || occursin("Z", p_val) pollutant_str *= "O3, " end
            if occursin("CO", p_val) pollutant_str *= "CO, " end
            if occursin("NO", p_val) pollutant_str *= "NO2, " end
            if occursin("SO", p_val) pollutant_str *= "SO2, " end
            if occursin("10", p_val) pollutant_str *= "PM10, " end
            if occursin("2.5", p_val) pollutant_str *= "PM2.5, " end
            df[r, :pollutant] = rstrip(pollutant_str, [',', ' '])
            if !ismissing(df[r, :stations])
                s_val = replace(string(df[r, :stations]), " #" => "")
                df[r, :stations] = split(s_val, "/")[begin]
            end
        end

        df.date = fill(date_to_fetch, nrow(df))
        select!(df, [:city, :level, :index, :pollutant, :stations, :date])
        CSV.write(output_path, df)
        println("Saved: ", output_path, " (", nrow(df), " rows)")
        return true
    catch e
        println("Cleaning failed for $(date_to_fetch): ", e)
        isfile(output_path) && rm(output_path; force=true)
        return false
    end
end

function main()
    ist = tz"Asia/Kolkata"
    default_date = Date(now(ist))
    start_str = get(ENV, "START_DATE", "")
    end_str = get(ENV, "END_DATE", "")

    if isempty(start_str) && isempty(end_str)
        fetch_and_process_bulletin(default_date)
        return
    end

    start_date = isempty(start_str) ? default_date : Date(start_str)
    end_date = isempty(end_str) ? start_date : Date(end_str)
    if end_date < start_date
        error("END_DATE must be on or after START_DATE")
    end

    println("Backfill range: $(start_date) to $(end_date)")
    for d in start_date:Day(1):end_date
        fetch_and_process_bulletin(d)
    end
end

main()
