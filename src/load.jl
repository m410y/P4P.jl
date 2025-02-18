function load(io::IO; whitelist = Set(keys(PARSERS)), blacklist = Set([]))
    dict = Dict{String,Any}()
    wlist = setdiff(Set(whitelist), Set(blacklist))
    for line in eachline(io)
        card = parse_card(line)
        card in wlist || haskey(PARSERS, card) || continue
        parsed = PARSERS[card](line)
        card == "DATA" && (parsed = (parsed..., parse_data(io)))
        if card in SINGLES
            dict[card] = parsed
            continue
        end
        haskey(dict, card) || (dict[card] = [])
        push!(dict[card], parsed)
    end
    for card in intersect(SAMPLED, keys(dict))
        max_samples = findmax(first, dict[card])[1]
        samples = Vector{Any}(missing, max_samples)
        for (i, data...) in dict[card]
            if card != "ORT"
                samples[i] = data
                continue
            end
            ismissing(samples[i]) && (samples[i] = [])
            push!(samples[i], data)
        end
        dict[card] = card == "ORT" || max_samples > 1 ? samples : samples[1]
    end
    haskey(dict, "ORT") || return dict
    for (n, data) in enumerate(dict["ORT"])
        orient = Matrix{Float64}(undef, 3, 3)
        for ort_row in data
            orient[ort_row[1], :] .= ort_row[2:4]
        end
        dict["ORT"][n] = orient
    end
    if length(dict["ORT"]) == 1
        dict["ORT"] = dict["ORT"][1]
    end
    return dict
end

load(path::AbstractString; kwargs...) = load(open(path, "r"); kwargs...)
load(f::File{format"P4P"}; kwargs...) = load(open(f).io; kwargs...)