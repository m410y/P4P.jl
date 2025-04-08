function parse_card(line::AbstractString)
    return match(r"^([A-Z]+)", line[1:6]).captures[1]
end

parse_sample_num(chr) = isdigit(chr) && parse(Int, chr) > 0 ? parse(Int, chr) : 1
check_nothing(str) = str == "?" ? nothing : str

function parse_file_id(line::AbstractString)
    program = strip(line[8:19])
    program_version = parse(VersionNumber, strip(line[21:32]))
    version = parse(VersionNumber, strip(line[34:45]))
    m = match(r"(\d{2})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2})", line[47:63])
    datetime = parse.(Int, m.captures)
    year = datetime[3] + (datetime[3] < 80 ? 2000 : 1900)
    timestamp = DateTime(year, datetime[1:2]..., datetime[4:6]...)
    project = strip(line[65:76])
    return program, program_version, version, timestamp, project
end

function parse_site_id(line::AbstractString)
    user = check_nothing(strip(line[8:43]))
    site = check_nothing(strip(line[44:79]))
    return user, site
end

function parse_title(line::AbstractString)
    return check_nothing(strip(line[6:47]))
end

function parse_text_line(line::AbstractString)
    return check_nothing(lstrip(line[8:end]))
end

function parse_sample_map(line::AbstractString)
    smap = parse.(Int, split(line[6:end]))
    deleteat!(smap, findall(iszero, smap))
    return Tuple(smap)
end

function parse_cell(line::AbstractString)
    sample_num = parse_sample_num(line[5])
    cell_params = parse.(Float64, split(line[6:end]))
    return sample_num, cell_params[1:3]..., cell_params[4:6]..., cell_params[7]
end

function parse_cell_error(line::AbstractString)
    sample_num = parse_sample_num(line[7])
    cell_params = parse.(Float64, split(line[8:end]))
    return sample_num, cell_params[1:3]..., cell_params[4:6]..., cell_params[7]
end

function parse_orient_row(line::AbstractString)
    ort_row = parse(Int, line[4])
    sample_num = parse_sample_num(line[5])
    vec = parse.(Float64, split(line[6:end]))
    return sample_num, ort_row, vec...
end

function parse_zeros(line::AbstractString)
    sample_num = parse_sample_num(line[6])
    zeros = parse.(Float64, split(line[8:end]))
    return sample_num, zeros[1:3]..., zeros[4:6]...
end

function parse_qvec(line::AbstractString)
    sample_num = parse_sample_num(line[5])
    qvec = parse.(Float64, split(line[6:end]))
    return sample_num, qvec...
end

function parse_source(line::AbstractString)
    tokens = split(line[8:end])
    anode = tokens[1]
    params = parse.(Float64, tokens[2:end])
    return anode, params...
end

function parse_limits(line::AbstractString)
    angles = parse.(Float64, split(line[8:end]))
    return Tuple(angles)
end

function parse_crystal_size(line::AbstractString)
    tokens = split(line[8:end])
    return Tuple(map(t -> t == "?" ? nothing : parse(Float64, t), tokens))
end

function parse_detector_params(line::AbstractString)
    tokens = split(line[8:end])
    coords = parse.(Float64, tokens[1:2])
    dist = parse(Float64, tokens[3]) * 10
    return coords..., dist, parse.(Int, tokens[4:5])...
end

function parse_detector_correction(line::AbstractString)
    sample_num = parse_sample_num(line[6])
    params = parse.(Float64, split(line[8:end]))
    return sample_num, params[1:2]..., params[3] * 10, params[4:6]...
end

function parse_bravais(line::AbstractString)
    sample_num = parse_sample_num(line[7])
    tokens = split(line[8:end])
    isempty(tokens) && return sample_num
    centering = tokens[1] == "Rhombohedral" ? 'R' : first(tokens[2])
    bravais = Dict(
        "Triclinic" => 'a',
        "Monoclinic(a-unique)" => 'm',
        "Monoclinic(b-unique)" => 'm',
        "Monoclinic(c-unique)" => 'm',
        "Orthorhombic" => 'o',
        "Tetragonal" => 't',
        "Hexagonal" => 'h',
        "Rhombohedral" => 'h',
        "Cubic" => 'c',
    )[tokens[1]]
    return sample_num, bravais, centering
end

function parse_mosaicity(line::AbstractString)
    return Tuple(parse.(Float64, split(line[8:end])))
end

function parse_symmetry(line::AbstractString)
    sample_num = parse_sample_num(5)
    lc, pg = split(line[8:end])
    replace!(lc, r"([13])-" => s"-\g<1>")
    replace!(lc, r"([246])m" => s"\g<1>/m")
    return sample_num, lc, pg
end

function parse_face(line::AbstractString)
    tokens = split(line[8:end])
    if length(tokens) == 4
        h, k, l = parse.(Int, tokens[1:3])
        dist = parse(Float64, tokens[4])
    else
        h = parse(Int, line[9:14])
        k = parse(Int, line[15:20])
        l = parse(Int, line[21:26])
        dist = parse(Float64, line[27:end])
    end
    return h, k, l, dist
end

function parse_saint_decay(line::AbstractString)
    tokens = split(line[8:end])
    refs = parse(Int, tokens[1])
    params = parse.(Float64, tokens[2:end])
    return refs, params...
end

function parse_saint_inegration(line::AbstractString)
    tokens = split(line[8:end])
    ints = parse.(Int, tokens[1:2])
    floats = parse.(Float64, tokens[3:4])
    return ins..., floats...
end

function parse_saint_refinement(line::AbstractString)
    tokens = split(line[8:end])
    refs = parse(Int, tokens[1])
    params = parse.(Float64, tokens[2:3])
    intvec = parse.(Int, tokens[4:end])
    return refs, params..., intvec...
end

function parse_reflex(line::AbstractString)
    max_resolution = Dict("05" => 512, "1K" => 1024, "2K" => 2048, "4K" => 4096)[line[4:5]]
    is_partial = 'A' in line[7:10]
    is_span = 'C' in line[7:10]
    is_split = 'S' in line[7:10]
    is_indexed = 'H' in line[7:10]
    flags = is_partial, is_span, is_split, is_indexed
    hkl = parse.(Int, split(line[12:23]))
    angles = parse.(Float64, [line[24:31], line[32:39], line[40:47], line[48:55]])
    params = parse.(Float64, split(line[56:end]))
    return max_resolution, flags..., hkl..., angles..., params...
end

function parse_data_header(line::AbstractString)
    tokens = split(line[5:end])
    floats = parse.(Float64, tokens[5:7])
    ints = parse.(Int, tokens[8:10])
    return tokens[1:4]..., floats..., ints...
end

function parse_data(file::IOStream)
    data = Float64[]
    for line in eachline(file)
        tokens = split(line)
        vals = parse.(Int, tokens) / 10
        append!(data, vals)
        length(tokens) != 10 && break
    end
    return data
end

PARSERS = Dict(
    "FILEID" => parse_file_id,
    "SITEID" => parse_site_id,
    "TITLE" => parse_title,
    "CHEM" => parse_text_line,
    "SMAP" => parse_sample_map,
    "CELL" => parse_cell,
    "CELLSD" => parse_cell_error,
    "ORT" => parse_orient_row,
    "ZEROS" => parse_zeros,
    "QVEC" => parse_qvec,
    "SOURCE" => parse_source,
    "LIMITS" => parse_limits,
    "MORPH" => parse_text_line,
    "DNSMET" => parse_text_line,
    "CCOLOR" => parse_text_line,
    "CSIZE" => parse_crystal_size,
    "ADPAR" => parse_detector_params,
    "ADCOR" => parse_detector_correction,
    "BRAVAI" => parse_bravais,
    "MOSAIC" => parse_mosaicity,
    "SYMM" => parse_symmetry,
    "FACE" => parse_face,
    "SAINTD" => parse_saint_decay,
    "SAINOV" => parse_saint_inegration,
    "SAINGL" => parse_saint_refinement,
    "REF" => parse_reflex,
    "DATA" => parse_data_header,
)

SINGLES = Set([
    "FILEID",
    "SITEID",
    "TITLE",
    "CHEM",
    "SMAP",
    "SOURCE",
    "LIMITS",
    "MORPH",
    "DNSMET",
    "CCOLOR",
    "CSIZE",
    "ADPAR",
    "MOSAIC",
])

SAMPLED = Set(["CELL", "CELLSD", "ZEROS", "ORT", "QVEC", "ADCOR", "BRAVAI", "SYMM"])